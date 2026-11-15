# Segurança

Mantenha as chaves no servidor, em variáveis protegidas ou gerenciador de segredos.
Nunca as inclua no cliente de navegador, Git, URLs, relatórios ou mensagens de log.
Use chaves com os escopos e domínios necessários. Revogação e autorização atual
continuam sendo controladas pela API.

HTTPS é obrigatório, com verificação de cadeia/hostname. O SDK não segue
redirecionamentos, não envia cookies, não herda proxies do ambiente e não
permite substituir cabeçalhos reservados. A opção HTTP de teste se limita a
loopback explicitamente autorizado. Uma CA privada não desabilita a verificação TLS.

Valide assinaturas sobre o corpo bruto antes de processar eventos. Preserve
deduplicação durável, autorização da aplicação e limites no servidor HTTP que
recebe o webhook. Repetições legítimas podem ocorrer dentro da janela de assinatura.
No Action Mailbox, configure armazenamento protegido e retenção de mensagens.

Não registre corpos MIME/JSON, endereços, URLs temporárias ou segredos para
diagnosticar falhas. A gem não registra requisições automaticamente. `inspect`
de configuração, cliente, transporte e resposta omite credenciais/conteúdo.

Em caso de falha em download por blocos, descarte o arquivo parcial antes de
usá-lo. Em caso de timeout de envio, consulte a intenção por idempotência antes de
repetir. Não há repetição automática no transporte; tarefas Rails podem possuir
sua própria política de repetição, que deve preservar a chave/intenção.

Relate vulnerabilidades pelo canal privado de manutenção do projeto, com uma
reprodução sintética. Não publique credenciais ou dados de clientes em issues.
