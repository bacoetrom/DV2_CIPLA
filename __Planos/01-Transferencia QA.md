# 01-Transferencia QA

**Projeto:** DV2 - CIPLA
**Objetivo:** exigir Assinatura Eletrônica (Justificativa + Senha) ao final da Liberação/Rejeição do CQ (MATA175), no mesmo padrão já implementado no `SIGAEST/Ponto de Entrada/A261TOK.prw` (Transferência Modelo II — MATA261), com auditoria na tabela ZZ2.
**Autor:** Pablo Regis
**Data:** 08/10/2026
**Status:** Planejamento — aguardando decisões em aberto

---

## 1. Escolha do Ponto de Entrada

O MATA175 não possui um equivalente direto ao A261TOK. Pontos de entrada avaliados (fonte padrão `mata175.prx`, release 2510):

| PE | Momento | Pode cancelar? | Adequado? |
|---|---|---|---|
| **MT175ATU** (linha ~1003) | Uma única vez, após o OK da tela e **antes** de `A175Grava()`; também executado via ExecAuto | ✅ retorno `.F.` cancela (`nOpcA := 3`) | ✅ **Recomendado** — mesmo comportamento do A261TOK |
| MT175TOK (linha ~1842) | Dentro de `A175TudOk()`, também usado em validações intermediárias | ✅ | ❌ risco de abrir a tela de senha mais de uma vez |
| A175GRV (linha ~1266) | Após `fGravaCQ` | ❌ retorno ignorado | ❌ movimento já gravado, não permite veto |

O MT175ATU é executado fora de `Begin Transaction`, portanto a tela de senha **não** viola a regra CA1002 (UI dentro de transação).

---

## 2. Diferença crítica em relação ao MATA261

No MATA175 o `aCols` contém **todo o histórico do SD7** (Qtd Original, liberações/rejeições anteriores etc.). Apenas as linhas **novas** devem ser auditadas, portanto **não** é possível passar `aCols` diretamente ao `SetItens`, como no A261TOK.

O PE montará um array normalizado usando o **mesmo filtro** que o padrão aplica em `A175Grava()` (linha ~1215):

```advpl
nX > If(lEstorno, 1, nAColsIni) .And. !aCols[nX, Len(aCols[nX])]
```

Layout de cada item:

```advpl
{ cA175Prod, aCols[nX, nCQPosQtde], cA175Loc, aCols[nX, nCQPosLDes] }
```

com `SetPosicoesGrid(1, 2, 3, 4)`.

**Privates do MATA175 disponíveis no PE:** `aCols`, `aHeader`, `nAColsIni`, `lEstorno`, `l175Auto`, `cA175Num`, `cA175Prod`, `cA175Loc`, `nPosTipo`, `nCQPosQtde`, `nCQPosLDes`.

---

## 3. Implementação — novo fonte `SIGAEST/Ponto de Entrada/MT175ATU.prw`

- `User Function MT175ATU() as Logical` — sem prefixo `U_`, nome do arquivo igual ao PE, ProtheusDoc completo, `#include "totvs.ch"`, encoding **CP-1252**.
- Documento: `cA175Num` (D7_NUMERO); rotina registrada: `"MT175ATU"`.
- Modo automático: `IsBlind() .Or. l175Auto` (mais robusto que o A261TOK, pois ExecAuto chamado a partir de uma tela não é "blind").
- Sem itens novos → retorna `.T.` sem abrir tela (comportamento já existente na classe).
- Fluxo:
  1. `oAssina := ZZ2AssinaEletronica():New("MT175ATU", cA175Num, cOrigemProc)`
  2. `oAssina:SetTitulo("Assinatura Eletrônica - Liberação/Rejeição CQ")`
  3. `oAssina:SetPosicoesGrid(1, 2, 3, 4)`
  4. `oAssina:SetItens(aItens)`
  5. Automático → `GravaAutomatico("LIBERACAO CQ GERADA VIA PROCESSO AUTOMATICO")`
  6. Interativo → `Confirma()`; se `.F.`, `Help` no mesmo padrão do A261TOK.

**Reaproveitados sem alteração:**
- `SIGAEST/Rotina/CI04A003.tlpp` — classe `ZZ2AssinaEletronica`
- `SIGAEST/Rotina/CI04A002.tlpp` — `U_ZZ2GravaLog`

---

## 4. Pacote / Entrega

- Incluir `MT175ATU.prw` no pacote de compilação.
- Atualizar `Diferencial/manifest_update.txt`, caso faça parte do fluxo de entrega.

---

## 5. Roteiro de testes

| # | Cenário | Resultado esperado |
|---|---|---|
| 1 | Liberação manual com justificativa + senha válidas | SD7 gravado + 1 registro ZZ2 por item novo |
| 2 | Cancelar a tela / senha inválida | Nada gravado em SD7 nem ZZ2 |
| 3 | Liberação parcial com várias linhas | ZZ2 contém apenas as linhas novas, nunca o histórico |
| 4 | Rejeição | ZZ2 registra o armazém de destino da rejeição |
| 5 | ExecAuto do MATA175 | Grava sem tela, `ZZ2_ORIGEM = '2'` |
| 6 | Ambiente com integração ACD (`CBMT175ATU`) | Continua funcionando normalmente |

---

## 6. Decisões em aberto

1. **Estorno:** o MT175ATU também é executado em *Estornar* (`A175Estorna`). O estorno também deve exigir justificativa, ou o PE deve retornar `.T.` direto quando `lEstorno`?
2. **Tipo do movimento:** a ZZ2 não possui campo que diferencie Liberação (1) de Rejeição (2). Opções: criar campo (ex.: `ZZ2_TIPO`), concatenar o tipo na justificativa, ou não registrar.
3. **Escopo:** a regra vale para toda Liberação/Rejeição do CQ ou apenas para algum tipo específico?
