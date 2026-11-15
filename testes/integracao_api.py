#!/usr/bin/env python3
"""Controlador executado em Docker; API e PostgreSQL exclusivos com TLS, sem SMTP."""

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid


SDK = Path(__file__).resolve().parents[1]
ROTULO = "mailcore.ensaio=ruby-api"
RUST_PADRAO = "rust@sha256:8fa55b2f3ddf97471ab6a767bfa3f37e6bad0986ba823e75fea57e2a2a5c3073"
PG_PADRAO = "postgres:18.7-bookworm@sha256:f1ea2a1a4fb7b68d4836be1fdcb8a6466a89b072158bf9d97663600538c294c5"


class FalhaEnsaio(RuntimeError):
    pass


class Interrompido(FalhaEnsaio):
    pass


def exigir(condicao, mensagem):
    if not condicao:
        raise FalhaEnsaio(mensagem)


def executar(argumentos, entrada=None, prazo=120, cwd=None):
    # Ferramentas podem produzir dados privados em erros; nunca imprimir suas saídas.
    return subprocess.run(list(map(str, argumentos)), input=entrada, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=prazo, cwd=cwd, check=False)


def docker(*argumentos, entrada=None, prazo=120):
    retorno = executar(["docker", *argumentos], entrada=entrada, prazo=prazo)
    exigir(retorno.returncode == 0, "Operação Docker do ensaio falhou: " + str(argumentos[0]) + "; detalhes omitidos.")
    return retorno.stdout


def interromper(_sinal, _quadro):
    raise Interrompido("Ensaio interrompido; recursos exclusivos serão removidos.")


def ausencia_confirmada(tipo, nome):
    # Falha do daemon não prova ausência: só uma listagem bem-sucedida pode fazê-lo.
    argumentos = (["container", "ls", "--all", "--format", "{{.Names}}"] if tipo == "container"
                  else [tipo, "ls", "--format", "{{.Name}}"])
    retorno = executar(["docker", *argumentos], prazo=20)
    return retorno.returncode == 0 and nome not in retorno.stdout.decode().splitlines()


def escrever(caminho, conteudo, modo=0o600):
    caminho.write_bytes(conteudo if isinstance(conteudo, bytes) else conteudo.encode())
    caminho.chmod(modo)


def gerar_identidade(pasta, nome, cn, extensoes):
    chave, csr, crt = (pasta / f"{nome}.{ext}" for ext in ("key", "csr", "crt"))
    parametros = pasta / f"{nome}.cnf"
    escrever(parametros, extensoes)
    comandos = [
        ["openssl", "req", "-newkey", "rsa:2048", "-nodes", "-keyout", chave,
         "-out", csr, "-subj", f"/CN={cn}"],
        ["openssl", "x509", "-req", "-in", csr, "-CA", pasta / "ca.crt",
         "-CAkey", pasta / "ca.key", "-CAcreateserial", "-out", crt, "-days", "1",
         "-sha256", "-extfile", parametros],
    ]
    for comando in comandos:
        exigir(executar(comando).returncode == 0, "Não foi possível gerar identidade TLS sintética.")
    chave.chmod(0o600)
    crt.chmod(0o644)


def preparar_configuracao(pasta):
    # Todos os certificados, segredos e papéis são novos e exclusivos deste ensaio.
    config = pasta / "config"
    config.mkdir(mode=0o711)
    tls = config / "tls"
    tls.mkdir(mode=0o711)
    exigir(executar(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                     "-keyout", tls / "ca.key", "-out", tls / "ca.crt", "-days", "1",
                     "-sha256", "-subj", "/CN=Mailcore-Ruby-Ensaio"]).returncode == 0,
           "Não foi possível gerar a CA sintética.")
    (tls / "ca.key").chmod(0o600)
    (tls / "ca.crt").chmod(0o644)
    gerar_identidade(tls, "api", "mailcore-api",
                     "subjectAltName=DNS:mailcore-api\nextendedKeyUsage=serverAuth\n")
    gerar_identidade(tls, "banco", "banco-mailcore",
                     "subjectAltName=DNS:banco-mailcore\nextendedKeyUsage=serverAuth\n")
    exigir(executar(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048",
                     "-out", config / "postal-test.key"]).returncode == 0,
           "Não foi possível gerar a assinatura sintética de recebimento.")
    exigir(executar(["openssl", "pkey", "-in", config / "postal-test.key", "-pubout",
                     "-out", config / "postal-signing.pub"]).returncode == 0,
           "Não foi possível exportar a identidade sintética de recebimento.")
    (config / "postal-test.key").chmod(0o600)
    (config / "postal-signing.pub").chmod(0o644)
    senhas = {nome: secrets.token_hex(32) for nome in ("raiz", "migracao", "app")}
    escrever(config / "postgres-password", senhas["raiz"])
    escrever(config / "chave_dados.bin", secrets.token_bytes(32))
    for papel in ("migracao", "app"):
        escrever(config / f"banco-{papel}.url",
                 f"postgresql://mailcore_{papel}:{senhas[papel]}@banco-mailcore:5432/mailcore?sslmode=verify-full\n")
    inicio = config / "pg-inicio"
    inicio.mkdir(mode=0o755)
    escrever(inicio / "10-fixture.sql", f"""
CREATE ROLE mailcore_migracao LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD '{senhas['migracao']}';
CREATE ROLE mailcore_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD '{senhas['app']}';
ALTER DATABASE mailcore OWNER TO mailcore_migracao;
REVOKE ALL ON DATABASE mailcore FROM PUBLIC;
GRANT CONNECT ON DATABASE mailcore TO mailcore_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE,CREATE ON SCHEMA public TO mailcore_migracao;
ALTER DEFAULT PRIVILEGES FOR ROLE mailcore_migracao IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO mailcore_app;
""", 0o644)
    return config


def assinatura_fontes(backend):
    retorno = executar(["git", "-c", "safe.directory=" + str(backend), "ls-files", "-z",
                        "Cargo.toml", "Cargo.lock", "apps/api", "crates"], cwd=backend)
    exigir(retorno.returncode == 0, "Não foi possível identificar os fontes do backend.")
    digest = hashlib.sha256()
    for nome in sorted(retorno.stdout.split(b"\0")):
        if nome:
            digest.update(nome + b"\0")
            digest.update((backend / os.fsdecode(nome)).read_bytes())
    return digest.hexdigest()


def main():
    argumentos = argparse.ArgumentParser(description=__doc__)
    argumentos.add_argument("--backend", type=Path, default=SDK.parent.parent / "mailcore")
    argumentos.add_argument("--imagem-cliente", default="mailcore/ruby-testes:3.4")
    argumentos.add_argument("--imagem-runtime-api", default="mailcore/api:local")
    argumentos.add_argument("--imagem-compilador", default=RUST_PADRAO)
    argumentos.add_argument("--cache-cargo", type=Path)
    argumentos.add_argument("--relatorio", type=Path, default=SDK / "docs/integracao-api.json")
    opcoes = argumentos.parse_args()
    backend = opcoes.backend.resolve()
    exigir((backend / "tests/plataforma/testar_imagem_migracoes.py").is_file(), "Informe um checkout local válido do backend.")
    # Este import reutiliza somente consultas e validação do catálogo; não inicia a fixture antiga.
    sys.path.insert(0, str(backend / "tests/plataforma"))
    import testar_imagem_migracoes as fixture

    identificador = uuid.uuid4().hex
    prefixo = "mailcore-ruby-" + identificador
    rede, volume = prefixo + "-rede", prefixo + "-config"
    nomes = {nome: prefixo + "-" + nome for nome in ("guardar", "compilar", "preparar", "copiar", "hash", "banco", "migrar", "api", "cliente")}
    relatorio = {"data_utc": datetime.now(timezone.utc).isoformat(), "resultado": "falhou",
                 "ambiente": "api_postgres_tls_exclusivos_sem_worker_sem_portas", "instalacao_host": False,
                 "rede_interna": True, "portas_publicadas": False, "worker_executado": False,
                 "smtp_executado": False, "deploy_executado": False, "tls_api_verificado": False,
                 "tls_postgres": "nao_verificado", "cenarios": []}
    etiqueta = ["--label", ROTULO, "--label", "mailcore.identificador=" + identificador]
    endurecer = ["--read-only", "--cap-drop", "ALL", "--security-opt", "no-new-privileges:true",
                 "--memory", "512m", "--pids-limit", "256", "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m"]
    montagens_config = ["--mount", f"type=volume,src={volume},dst=/config,readonly"]
    signal.signal(signal.SIGTERM, interromper)
    signal.signal(signal.SIGINT, interromper)
    try:
        relatorio["etapa"] = "validar_imagens"
        imagens = {}
        for nome, referencia in (("cliente", opcoes.imagem_cliente), ("api_runtime", opcoes.imagem_runtime_api),
                                 ("compilador", opcoes.imagem_compilador), ("postgres", PG_PADRAO)):
            imagens[nome] = docker("image", "inspect", referencia, "--format", "{{.Id}}").decode().strip()
        relatorio["imagens"] = imagens
        revisao = executar(["git", "-c", "safe.directory=" + str(backend), "rev-parse", "HEAD"], cwd=backend)
        exigir(revisao.returncode == 0, "Não foi possível registrar a revisão backend.")
        relatorio["backend_revisao"] = revisao.stdout.decode().strip()
        relatorio["backend_fontes_sha256"] = assinatura_fontes(backend)
        relatorio["backend_fontes_alterados"] = bool(executar(["git", "-c", "safe.directory=" + str(backend), "status", "--porcelain", "--untracked-files=all", "--", "Cargo.toml", "Cargo.lock", "apps/api", "crates"], cwd=backend).stdout)
        cache = opcoes.cache_cargo or backend.parent.parent / ".cargo/registry"
        # O registry público em cache é montado sozinho; nunca montamos ~/.cargo inteiro/credentials.
        compilar = ["run", "--rm", "--name", nomes["compilar"], *etiqueta, "--network", "none",
                    "--user", f"{backend.stat().st_uid}:{backend.stat().st_gid}", "--cap-drop", "ALL",
                    "--security-opt", "no-new-privileges:true", "--memory", "3g", "--pids-limit", "512",
                    "--tmpfs", "/tmp:rw,nosuid,size=128m", "--mount", f"type=bind,src={backend},dst=/codigo,readonly",
                    "--mount", f"type=bind,src={backend / 'target'},dst=/codigo/target",
                    "--mount", f"type=bind,src={cache},dst=/registro,readonly", "--env", "CARGO_HOME=/tmp/mailcore-cargo",
                    "--env", "CARGO_NET_OFFLINE=true", "--workdir", "/codigo", "--entrypoint", "/bin/sh", imagens["compilador"],
                    "-c", "mkdir -p /tmp/mailcore-cargo && ln -s /registro /tmp/mailcore-cargo/registry && exec cargo build --offline --locked -j 2 -p mailcore-api"]
        relatorio["etapa"] = "compilar_api"
        docker(*compilar, prazo=600)
        exigir(assinatura_fontes(backend) == relatorio["backend_fontes_sha256"], "Os fontes backend mudaram durante a compilação.")
        relatorio["api_compilada_neste_ensaio"] = True
        relatorio["etapa"] = "criar_rede_volume"
        docker("network", "create", "--internal", "--driver", "bridge", *etiqueta, rede)
        exigir(json.loads(docker("network", "inspect", rede))[0]["Internal"], "A rede deve ser interna.")
        # Segredos e a cópia imutável do binário vivem somente em memória do daemon.
        docker("volume", "create", *etiqueta, "--driver", "local", "--opt", "type=tmpfs", "--opt", "device=tmpfs",
               "--opt", "o=size=768m,mode=0711", volume)
        # O driver desmonta tmpfs sem usuários. Este processo inerte mantém o mount
        # até todos os consumidores encerrarem; é removido por último na limpeza.
        docker("run", "-d", "--name", nomes["guardar"], *etiqueta, "--network", "none",
               "--read-only", "--cap-drop", "ALL", "--security-opt", "no-new-privileges:true",
               "--memory", "16m", "--pids-limit", "8", *montagens_config,
               "--entrypoint", "sleep", imagens["cliente"], "infinity")
        with tempfile.TemporaryDirectory(prefix="mailcore-ruby-", dir="/dev/shm") as temporario:
            relatorio["etapa"] = "preparar_identidades"
            pasta = Path(temporario)
            pasta.chmod(0o700)
            config = preparar_configuracao(pasta)
            shutil.copyfile(backend / "infrastructure/docker/postgres/entrada.sh", config / "entrada-postgres.sh")
            # A entrada lê os certificados em /config/tls; nomes são os da fixture real.
            shutil.copyfile(backend / "infrastructure/docker/postgres/pg_hba.conf", config / "pg_hba.conf")
            (config / "pg_hba.conf").chmod(0o644)
            arquivo = io.BytesIO()
            with tarfile.open(fileobj=arquivo, mode="w") as tar:
                for caminho in config.iterdir():
                    tar.add(caminho, arcname=caminho.name)
            relatorio["etapa"] = "popular_configuracao"
            docker("run", "--rm", "-i", "--name", nomes["preparar"], *etiqueta, "--network", "none",
                   "--mount", f"type=volume,src={volume},dst=/config", "--entrypoint", "tar", imagens["cliente"],
                   "-xf", "-", "-C", "/config", entrada=arquivo.getvalue())
            relatorio["etapa"] = "congelar_binario"
            docker("run", "--rm", "--name", nomes["copiar"], *etiqueta, "--network", "none",
                   "--mount", f"type=volume,src={volume},dst=/config", "--mount", f"type=bind,src={backend / 'target/debug/mailcore-api'},dst=/fonte,readonly",
                   "--entrypoint", "cp", imagens["cliente"], "/fonte", "/config/mailcore-api")
            digest = docker("run", "--rm", "--name", nomes["hash"], *etiqueta, "--network", "none", *montagens_config,
                            "--entrypoint", "sha256sum", imagens["cliente"], "/config/mailcore-api").decode().split()[0]
            relatorio["api_binario_sha256"] = digest
            banco = ["run", "-d", "--name", nomes["banco"], *etiqueta, "--network", rede,
                     "--network-alias", "banco-mailcore", *endurecer, "--shm-size", "128m",
                     "--tmpfs", "/var/lib/postgresql:uid=999,gid=999,mode=0700,size=512m",
                     "--tmpfs", "/var/run/postgresql:uid=999,gid=999,mode=0755,size=16m", *montagens_config,
                     "--mount", f"type=volume,src={volume},dst=/docker-entrypoint-initdb.d,volume-subpath=pg-inicio,readonly"]
            for capacidade in ("CHOWN", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"):
                banco.extend(["--cap-add", capacidade])
            banco.extend(["--env", "POSTGRES_DB=mailcore", "--env", "POSTGRES_PASSWORD_FILE=/config/postgres-password",
                          "--env", "POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=peer", "--entrypoint", "/bin/sh",
                          imagens["postgres"], "/config/entrada-postgres.sh", "postgres", "-c", "ssl=on",
                          "-c", "ssl_cert_file=/var/run/postgresql/tls/banco.crt", "-c", "ssl_key_file=/var/run/postgresql/tls/banco.key",
                          "-c", "hba_file=/config/pg_hba.conf", "-c", "shared_buffers=64MB", "-c", "max_connections=20",
                          "-c", "log_statement=none", "-c", "log_min_error_statement=panic", "-c", "log_parameter_max_length_on_error=0"])
            relatorio["etapa"] = "iniciar_postgres"
            docker(*banco)
            fim = time.monotonic() + 90
            while time.monotonic() < fim:
                if executar(["docker", "exec", nomes["banco"], "cat", "/proc/1/comm"]).stdout.strip() == b"postgres":
                    exigir(fixture.consultar(nomes["banco"], "SHOW ssl;") == "on", "O banco precisa exigir TLS.")
                    exigir(fixture.consultar(nomes["banco"], "SELECT count(*) FROM pg_tables WHERE schemaname='public';") == "0", "O banco exclusivo deve iniciar vazio.")
                    break
                time.sleep(0.25)
            else:
                raise FalhaEnsaio("O banco exclusivo não ficou pronto no prazo.")
            ambiente = {"MAILCORE_AMBIENTE": "teste", "MAILCORE_ORIGEM_PUBLICA": "https://localhost:17443",
                        "MAILCORE_ENDERECO": "0.0.0.0:3443", "MAILCORE_BANCO_URL_ARQUIVO": "/config/banco-app.url",
                        "MAILCORE_BANCO_MIGRACAO_URL_ARQUIVO": "/config/banco-migracao.url", "MAILCORE_BANCO_CA_ARQUIVO": "/config/tls/ca.crt",
                        "MAILCORE_CHAVE_DADOS_ARQUIVO": "/config/chave_dados.bin", "MAILCORE_TLS_CERTIFICADO_ARQUIVO": "/config/tls/api.crt",
                        "MAILCORE_TLS_CHAVE_ARQUIVO": "/config/tls/api.key", "MAILCORE_POSTAL_CHAVE_PUBLICA_ARQUIVO": "/config/postal-signing.pub",
                        "MAILCORE_MX_RECEBIMENTO": "mx.example.test"}
            base = [*etiqueta, "--network", rede, "--user", "0:0", *endurecer, *montagens_config]
            for chave, valor in ambiente.items():
                base.extend(["--env", chave + "=" + valor])
            relatorio["etapa"] = "migrar_schema"
            docker("run", "--rm", "--name", nomes["migrar"], *base, "--entrypoint", "/config/mailcore-api", imagens["api_runtime"], "migrar")
            catalogo = fixture.catalogo(nomes["banco"])
            fixture.validar_catalogo(fixture.esperado(), catalogo)
            relatorio["migracoes_aplicadas"] = len(catalogo)
            relatorio["tls_postgres"] = "verify-full"
            relatorio["etapa"] = "iniciar_api"
            docker("run", "-d", "--name", nomes["api"], *base, "--network-alias", "mailcore-api",
                   "--entrypoint", "/config/mailcore-api", imagens["api_runtime"])
            org, usuario, sessao, dominio, rota = (str(uuid.uuid4()) for _ in range(5))
            token, csrf = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
            nome_dominio = uuid.uuid4().hex + ".example.test"
            # Somente UUID/hex e valores sintéticos gerados aqui entram no SQL.
            fixture.consultar(nomes["banco"], f"""BEGIN;
INSERT INTO usuarios(id,nome,email,email_verificado_em) VALUES('{usuario}','Fixture Ruby','ruby-{identificador}@example.test',now());
INSERT INTO organizacoes(id,nome,aprovada_em,limite_diario) VALUES('{org}','Fixture Ruby',now(),1000);
INSERT INTO membros(organizacao_id,usuario_id,papel) VALUES('{org}','{usuario}','proprietario');
INSERT INTO sessoes(id,usuario_id,organizacao_id,token_hash,csrf_hash,expira_em) VALUES('{sessao}','{usuario}','{org}','{hashlib.sha256(token.encode()).hexdigest()}','{hashlib.sha256(csrf.encode()).hexdigest()}',now()+interval '30 minutes');
INSERT INTO dominios(id,organizacao_id,nome,token_verificacao,estado,verificado_em,verificado_dns_em,postal_verificado_em,propriedade_verificada_em,envio_habilitado,recebimento_habilitado,recebimento_estado,recebimento_verificado_em) VALUES('{dominio}','{org}','{nome_dominio}','fixture-ruby','verificado',now(),now(),now(),now(),true,true,'verificado',now());
INSERT INTO indice_rotas_recebimento(id,organizacao_id) VALUES('{rota}','{org}');
INSERT INTO rotas_recebimento(id,organizacao_id,dominio_id,tipo,geracao,configurada) VALUES('{rota}','{org}','{dominio}','dominio',0,true);
COMMIT;""")
            entrada = {"token": token, "csrf": csrf, "organizacao": org, "dominio": dominio,
                       "nome_dominio": nome_dominio, "rota": rota,
                       "certificado_ca": (config / "tls/ca.crt").read_text(),
                       "chave_postal": (config / "postal-test.key").read_text()}
            comando = ["run", "--rm", "-i", "--name", nomes["cliente"], *etiqueta, "--network", rede,
                       "--user", "1000:1000", *endurecer, "--mount", f"type=bind,src={SDK},dst=/sdk,readonly",
                       "--workdir", "/sdk", "--entrypoint", "ruby", imagens["cliente"], "testes/integracao_api.rb"]
            relatorio["etapa"] = "cliente_ruby"
            processo_cliente = executar(["docker", *comando], entrada=json.dumps(entrada).encode(), prazo=180)
            saida = processo_cliente.stdout
            del entrada, token, csrf
            try:
                resultado = json.loads(saida)
            except ValueError:
                raise FalhaEnsaio("O cliente não retornou um relatório sanitizado.") from None
            relatorio.update(resultado)
            exigir(processo_cliente.returncode == 0 and resultado.get("resultado") == "aprovado",
                   "O contrato Ruby/API real não passou nos cenários registrados.")
            relatorio["tls_api_verificado"] = True
            relatorio["persistencia_sintetica"] = json.loads(fixture.consultar(nomes["banco"], f"""
SELECT json_build_object('mensagens',(SELECT count(*) FROM mensagens WHERE organizacao_id='{org}'),
'tarefas_envio',(SELECT count(*) FROM tarefas WHERE organizacao_id='{org}' AND tipo='email.enviar'),
'recebidos',(SELECT count(*) FROM mensagens_recebidas WHERE organizacao_id='{org}'),
'recebidos_pendentes',(SELECT count(*) FROM mensagens_recebidas WHERE organizacao_id='{org}' AND estado_processamento='pendente'));
"""))
            for nome in ("banco", "api"):
                estado = json.loads(docker("inspect", nomes[nome]))[0]
                exigir(set(estado["NetworkSettings"]["Networks"]) == {rede} and not estado["HostConfig"].get("PortBindings"),
                       "Um serviço ficou fora do isolamento exigido.")
            relatorio["etapa"] = "concluido"
    except BaseException as erro:
        relatorio["resultado"] = "falhou"
        relatorio["falha"] = str(erro) if isinstance(erro, FalhaEnsaio) else "Falha de infraestrutura; detalhes privados omitidos."
    finally:
        # Um SIGTERM único também passa por esta limpeza. Não toca recursos de outros ensaios.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        limpeza = True
        for nome in reversed(list(nomes.values())):
            try:
                encontrado = executar(["docker", "inspect", nome], prazo=20)
                if encontrado.returncode:
                    limpeza = ausencia_confirmada("container", nome) and limpeza
                    continue
                estado = json.loads(encontrado.stdout)[0]
                if estado["Config"]["Labels"].get("mailcore.identificador") != identificador:
                    limpeza = False
                    continue
                limpeza = executar(["docker", "rm", "--force", nome], prazo=30).returncode == 0 and limpeza
            except Exception:
                limpeza = False
        for tipo, nome in (("volume", volume), ("network", rede)):
            try:
                encontrado = executar(["docker", tipo, "inspect", nome], prazo=20)
                if encontrado.returncode:
                    limpeza = ausencia_confirmada(tipo, nome) and limpeza
                    continue
                if json.loads(encontrado.stdout)[0]["Labels"].get("mailcore.identificador") != identificador:
                    limpeza = False
                    continue
                limpeza = executar(["docker", tipo, "rm", nome], prazo=30).returncode == 0 and limpeza
            except Exception:
                limpeza = False
        relatorio["limpeza_concluida"] = limpeza
        if not limpeza:
            relatorio["resultado"] = "falhou"
        destino = opcoes.relatorio.resolve()
        destino.parent.mkdir(parents=True, exist_ok=True)
        with os.fdopen(os.open(destino, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600), "w") as arquivo:
            json.dump(relatorio, arquivo, ensure_ascii=False, indent=2)
            arquivo.write("\n")
        os.chown(destino, SDK.stat().st_uid, SDK.stat().st_gid)
        print(json.dumps(relatorio, ensure_ascii=False))
    return 0 if relatorio["resultado"] == "aprovado" else 1


if __name__ == "__main__":
    sys.exit(main())
