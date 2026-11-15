# frozen_string_literal: true

require 'minitest/autorun'
require 'mailcore'

# Contrato extraído por AST do SDK Node a234dc2, conferido no backend e001da8.
# Os valores sintéticos exercitam segmentos, null, false e paginação sem modificar os DTOs.
class TestesRecursos < Minitest::Test
  CASOS = [
    [:ExecucoesAutomacoes, :listar, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/automations/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/runs", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:ExecucoesAutomacoes, :obter, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/automations/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/runs/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Automacoes, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/automations", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Automacoes, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/automations", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Automacoes, :obter, ["parte-0/ação+?@example.test"], "GET", "/automations/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Automacoes, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/automations/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Automacoes, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/automations/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Automacoes, :duplicar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/automations/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/duplicate", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Automacoes, :parar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/automations/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/stop", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:EmailsCaixa, :listar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/emails", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:EmailsCaixa, :obter, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", "parte-2/ação+?@example.test"], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/emails/parte-2%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:EmailsCaixa, :responder, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", "parte-2/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/emails/parte-2%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/reply", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:EmailsCaixa, :encaminhar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", "parte-2/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/emails/parte-2%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/forward", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:EtiquetasConversaCaixa, :adicionar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", ["etiqueta-a", "etiqueta-b"]], "POST", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels", { corpo: { ids: ["etiqueta-a", "etiqueta-b"] } }],
    [:EtiquetasConversaCaixa, :substituir, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", ["etiqueta-a", "etiqueta-b"]], "PUT", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels", { corpo: { ids: ["etiqueta-a", "etiqueta-b"] } }],
    [:EtiquetasConversaCaixa, :remover, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", "parte-2/ação+?@example.test"], "DELETE", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels/parte-2%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:ConversasCaixa, :listar, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:ConversasCaixa, :buscar, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/search", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:ConversasCaixa, :obter, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:ConversasCaixa, :atualizar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:ConversasCaixa, :remover, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "DELETE", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/threads/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:EtiquetasCaixa, :listar, ["parte-0/ação+?@example.test"], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels", {  }],
    [:EtiquetasCaixa, :obter, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:EtiquetasCaixa, :criar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:EtiquetasCaixa, :atualizar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:EtiquetasCaixa, :remover, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "DELETE", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/labels/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:RascunhosCaixa, :listar, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/drafts", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:RascunhosCaixa, :obter, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/drafts/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:RascunhosCaixa, :criar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/drafts", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:RascunhosCaixa, :atualizar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/drafts/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:RascunhosCaixa, :remover, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "DELETE", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/drafts/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:RascunhosCaixa, :enviar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/drafts/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/send", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Caixas, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/inboxes", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Caixas, :obter, ["parte-0/ação+?@example.test"], "GET", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Caixas, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/inboxes", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Caixas, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Caixas, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/inboxes/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Campanhas, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/broadcasts", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/broadcasts", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Campanhas, :obter, ["parte-0/ação+?@example.test"], "GET", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Campanhas, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Campanhas, :duplicar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/duplicate", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :revisar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/review", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :enviar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/send", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :cancelar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/cancel", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :prever, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/preview", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :ler_previa, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/broadcast-previews/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { formato: :texto }],
    [:Campanhas, :testar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Campanhas, :obter_metricas, ["parte-0/ação+?@example.test"], "GET", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/metrics", {  }],
    [:Campanhas, :listar_destinatarios, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/recipients", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Campanhas, :listar_links_clicados, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/broadcasts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/clicked-links", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:ChavesApi, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/api-keys", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:ChavesApi, :listar, [], "GET", "/api-keys", {  }],
    [:ChavesApi, :renomear, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/api-keys/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:ChavesApi, :revogar, ["parte-0/ação+?@example.test"], "DELETE", "/api-keys/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:ConcessoesCli, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/cli/oauth/grants", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:ConcessoesCli, :revogar, ["parte-0/ação+?@example.test"], "POST", "/cli/oauth/grants/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/revoke", {  }],
    [:SegmentosContato, :listar, ["parte-0/ação+?@example.test"], "GET", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/segments", {  }],
    [:SegmentosContato, :adicionar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "POST", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/segments", { aceitar_vazio: true, corpo: { segmento_id: "parte-1/ação+?@example.test" } }],
    [:SegmentosContato, :remover, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "DELETE", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/segments/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:TopicosContato, :listar, ["parte-0/ação+?@example.test"], "GET", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/topics", {  }],
    [:TopicosContato, :atualizar, ["parte-0/ação+?@example.test", [{ topico_id: "topico-a", assinatura: "opt_out" }]], "PATCH", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/topics", { corpo: { topicos: [{ topico_id: "topico-a", assinatura: "opt_out" }] } }],
    [:Contatos, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/contacts", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Contatos, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/contacts", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Contatos, :obter, ["parte-0/ação+?@example.test"], "GET", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Contatos, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Contatos, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/contacts/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Contatos, :adicionar_em_lote, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/contacts/batch", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Contatos, :alterar_em_lote, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/contacts/bulk", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:ExportacoesContatos, :criar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "POST", "/contacts/exports", { corpo: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:ExportacoesContatos, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/contacts/exports", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:ExportacoesContatos, :obter, ["parte-0/ação+?@example.test"], "GET", "/contacts/exports/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:ExportacoesContatos, :baixar, ["parte-0/ação+?@example.test"], "GET", "/contacts/exports/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/download", { formato: :bytes }],
    [:ExportacoesContatos, :baixar_fluxo, ["parte-0/ação+?@example.test"], "GET", "/contacts/exports/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/download", { formato: :fluxo }],
    [:ImportacoesContatos, :prever, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/contacts/imports/preview", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:ImportacoesContatos, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/contacts/imports", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:ImportacoesContatos, :obter, ["parte-0/ação+?@example.test"], "GET", "/contacts/imports/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Segmentos, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/segments", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Segmentos, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/segments", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Segmentos, :obter, ["parte-0/ação+?@example.test"], "GET", "/segments/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Segmentos, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/segments/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Segmentos, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/segments/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Topicos, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/topics", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Topicos, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/topics", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Topicos, :obter, ["parte-0/ação+?@example.test"], "GET", "/topics/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Topicos, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/topics/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Topicos, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/topics/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:PropriedadesContatos, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/contact-properties", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:PropriedadesContatos, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/contact-properties", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:PropriedadesContatos, :obter, ["parte-0/ação+?@example.test"], "GET", "/contact-properties/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:PropriedadesContatos, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/contact-properties/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:PropriedadesContatos, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/contact-properties/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Dominios, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/domains", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Dominios, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/domains", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Dominios, :obter, ["parte-0/ação+?@example.test"], "GET", "/domains/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Dominios, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/domains/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Dominios, :registros_dns, ["parte-0/ação+?@example.test"], "GET", "/domains/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/dns", {  }],
    [:Dominios, :verificar, ["parte-0/ação+?@example.test"], "POST", "/domains/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/verify", {  }],
    [:Dominios, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/domains/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Emails, :enviar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/emails", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Emails, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/emails", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Emails, :obter, ["parte-0/ação+?@example.test"], "GET", "/emails/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Emails, :reagendar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/emails/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Emails, :cancelar, ["parte-0/ação+?@example.test"], "POST", "/emails/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/cancel", {  }],
    [:Emails, :obter_por_idempotencia, ["parte-0/ação+?@example.test"], "GET", "/emails/idempotency/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Emails, :eventos, ["parte-0/ação+?@example.test"], "GET", "/emails/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/events", {  }],
    [:Emails, :baixar_anexo, ["parte-0/ação+?@example.test", 2], "GET", "/emails/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/attachments/2", { formato: :bytes }],
    [:Lotes, :enviar, [[{ texto: "ação", opcional: nil, ativo: false }]], "POST", "/emails/batch", { corpo: [{ texto: "ação", opcional: nil, ativo: false }] }],
    [:Lotes, :obter_por_idempotencia, ["parte-0/ação+?@example.test"], "GET", "/emails/batch/idempotency/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Eventos, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/events", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Eventos, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/events", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Eventos, :obter, ["parte-0/ação+?@example.test"], "GET", "/events/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Eventos, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/events/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Eventos, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/events/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Eventos, :enviar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/events/send", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:VersoesModelo, :listar, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/versions", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:VersoesModelo, :obter, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/versions/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:VersoesModelo, :restaurar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/versions/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/restore", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:VersoesModelo, :prever, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/versions/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/preview", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:PastasModelo, :listar, [], "GET", "/template-folders", {  }],
    [:PastasModelo, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/template-folders", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:PastasModelo, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/template-folders/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:PastasModelo, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/template-folders/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Modelos, :prever, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/preview", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Modelos, :obter_previa, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/template-previews/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { formato: :texto }],
    [:Modelos, :testar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Modelos, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/templates", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Modelos, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/templates", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Modelos, :obter, ["parte-0/ação+?@example.test"], "GET", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Modelos, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Modelos, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Modelos, :publicar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/publish", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Modelos, :duplicar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "POST", "/templates/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/duplicate", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Recebimento, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/receiving", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Recebimento, :obter, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/receiving/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Recebimento, :listar_anexos, ["parte-0/ação+?@example.test"], "GET", "/receiving/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/attachments", {  }],
    [:Recebimento, :obter_anexo, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/receiving/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/attachments/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Recebimento, :baixar_original, ["parte-0/ação+?@example.test"], "GET", "/receiving/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/raw", { formato: :bytes }],
    [:Recebimento, :baixar_anexo, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/receiving/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/attachments/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/download", { formato: :bytes }],
    [:Recebimento, :baixar_original_fluxo, ["parte-0/ação+?@example.test"], "GET", "/receiving/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/raw", { formato: :fluxo }],
    [:Recebimento, :baixar_anexo_fluxo, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/receiving/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/attachments/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/download", { formato: :fluxo }],
    [:EventosWebhook, :listar, ["parte-0/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/webhooks/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/events", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:EventosWebhook, :obter, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "GET", "/webhooks/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/events/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:EventosWebhook, :listar_tentativas, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test", { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/webhooks/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/events/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/attempts", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:EventosWebhook, :reenviar, ["parte-0/ação+?@example.test", "parte-1/ação+?@example.test"], "POST", "/webhooks/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/events/parte-1%2Fa%C3%A7%C3%A3o%2B%3F%40example.test/replay", {  }],
    [:Webhooks, :criar, [{ texto: "ação", opcional: nil, ativo: false }], "POST", "/webhooks", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Webhooks, :listar, [{ limite: 2, antes: "cursor/ação", ativo: false, opcional: nil }], "GET", "/webhooks", { consulta: { limite: 2, antes: "cursor/ação", ativo: false, opcional: nil } }],
    [:Webhooks, :obter, ["parte-0/ação+?@example.test"], "GET", "/webhooks/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
    [:Webhooks, :atualizar, ["parte-0/ação+?@example.test", { texto: "ação", opcional: nil, ativo: false }], "PATCH", "/webhooks/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", { corpo: { texto: "ação", opcional: nil, ativo: false } }],
    [:Webhooks, :remover, ["parte-0/ação+?@example.test"], "DELETE", "/webhooks/parte-0%2Fa%C3%A7%C3%A3o%2B%3F%40example.test", {  }],
  ].freeze

  class TransporteColetor
    attr_reader :chamadas, :retorno

    def initialize
      @chamadas = []
      @retorno = Object.new
    end

    def executar(verbo, caminho, corpo: nil, consulta: nil, formato: :json, aceitar_vazio: false, **opcoes)
      @chamadas << {
        verbo: verbo, caminho: caminho, corpo: corpo, consulta: consulta,
        formato: formato, aceitar_vazio: aceitar_vazio, opcoes: opcoes,
      }
      if formato == :fluxo
        yield 'abc'.b
        yield 'def'.b
      end
      @retorno
    end
  end

  CASOS.each do |nome_classe, nome_metodo, argumentos, verbo, caminho, configuracao|
    define_method("test_contrato_#{nome_classe}_#{nome_metodo}") do
      transporte = TransporteColetor.new
      recurso = Mailcore::Recursos.const_get(nome_classe).new(transporte)
      opcoes = {
        chave_idempotencia: 'negocio-123', tempo_limite: 2.5,
        limite_resposta_bytes: 4096, cabecalhos: { 'X-Correlacao' => 'sintetica' },
      }
      partes = []
      retorno = if configuracao[:formato] == :fluxo
        recurso.public_send(nome_metodo, *argumentos, **opcoes) { |bytes| partes << bytes }
      else
        recurso.public_send(nome_metodo, *argumentos, **opcoes)
      end

      assert_same transporte.retorno, retorno
      assert_equal 1, transporte.chamadas.length
      esperado = {
        verbo: verbo, caminho: caminho, corpo: nil, consulta: nil,
        formato: :json, aceitar_vazio: false, opcoes: opcoes,
      }.merge(configuracao)
      assert_equal esperado, transporte.chamadas.first
      assert_equal ['abc'.b, 'def'.b], partes if configuracao[:formato] == :fluxo
    end
  end

  def test_todos_os_metodos_http_estao_cobertos_pelo_contrato
    esperados = CASOS.group_by(&:first)
    esperados.each do |nome, casos|
      classe = Mailcore::Recursos.const_get(nome)
      filhos = case nome
      when :Contatos then %i[segmentos topicos importacoes exportacoes]
      when :Modelos then %i[versoes pastas]
      when :Webhooks then %i[eventos]
      when :Automacoes then %i[execucoes]
      when :Caixas then %i[conversas etiquetas rascunhos]
      when :ConversasCaixa then %i[emails etiquetas]
      else []
      end
      metodos = classe.public_instance_methods(false) - filhos
      assert_equal casos.map { |caso| caso[1] }.sort, metodos.sort, nome.to_s
    end
    assert_equal 151, CASOS.length
  end

  def test_recursos_aninhados_compartilham_transporte_sem_reter_estado_da_requisicao
    transporte = TransporteColetor.new
    contatos = Mailcore::Recursos::Contatos.new(transporte)
    contatos.segmentos.listar('contato')
    contatos.topicos.listar('contato')
    contatos.importacoes.obter('importacao')
    contatos.exportacoes.obter('exportacao')
    modelos = Mailcore::Recursos::Modelos.new(transporte)
    modelos.versoes.obter('modelo', 'versao')
    modelos.pastas.listar
    Mailcore::Recursos::Webhooks.new(transporte).eventos.obter('webhook', 'evento')
    Mailcore::Recursos::Automacoes.new(transporte).execucoes.obter('automacao', 'execucao')
    caixas = Mailcore::Recursos::Caixas.new(transporte)
    caixas.conversas.etiquetas.substituir('caixa', 'conversa', [])
    caixas.conversas.emails.obter('caixa', 'conversa', 'email')
    caixas.etiquetas.listar('caixa')
    caixas.rascunhos.obter('caixa', 'rascunho')
    Mailcore::Recursos::CliMailcore.new(transporte).concessoes.listar
    assert_equal 13, transporte.chamadas.length
    assert_equal({ ids: [] }, transporte.chamadas[8][:corpo])
  end

  def test_metodos_de_consulta_preservam_seus_filtros_padrao
    transporte = TransporteColetor.new
    Mailcore::Recursos::Emails.new(transporte).listar
    Mailcore::Recursos::Recebimento.new(transporte).obter('email')
    Mailcore::Recursos::Contatos.new(transporte).exportacoes.criar
    Mailcore::Recursos::Modelos.new(transporte).duplicar('modelo')
    Mailcore::Recursos::Modelos.new(transporte).versoes.prever('modelo', 'versao')
    Mailcore::Recursos::Campanhas.new(transporte).prever('campanha')
    Mailcore::Recursos::Automacoes.new(transporte).duplicar('automacao')
    Mailcore::Recursos::Caixas.new(transporte).rascunhos.criar('caixa')
    assert_equal({}, transporte.chamadas[0][:consulta])
    assert_equal({}, transporte.chamadas[1][:consulta])
    transporte.chamadas.drop(2).each { |chamada| assert_equal({}, chamada[:corpo]) }
  end

  def test_segmentos_invalidos_e_indices_de_anexo_sao_recusados_sem_http
    transporte = TransporteColetor.new
    emails = Mailcore::Recursos::Emails.new(transporte)
    [nil, '', '.', '..', "linha\nquebra", "controle\u0000"].each do |id|
      assert_raises(ArgumentError) { emails.obter(id) }
    end
    [-1, 1.5, '0', nil].each do |indice|
      assert_raises(ArgumentError) { emails.baixar_anexo('email', indice) }
    end
    assert_empty transporte.chamadas
  end

  def test_download_em_fluxo_exige_consumidor_antes_de_iniciar_http
    transporte = TransporteColetor.new
    recebimento = Mailcore::Recursos::Recebimento.new(transporte)
    assert_raises(ArgumentError) { recebimento.baixar_original_fluxo('email') }
    assert_raises(ArgumentError) { recebimento.baixar_anexo_fluxo('email', 'anexo') }
    assert_raises(ArgumentError) { Mailcore::Recursos::ExportacoesContatos.new(transporte).baixar_fluxo('exportacao') }
    assert_empty transporte.chamadas
  end
end
