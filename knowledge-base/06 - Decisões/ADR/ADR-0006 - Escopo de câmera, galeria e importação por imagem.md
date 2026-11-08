---
tipo: adr
area: importação por imagem
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/import/, lib/features/publish/, pubspec.yaml, README.md, AGENTS.md]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0006 — Escopo de câmera, galeria e importação por imagem

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

O fluxo atual aceita PDF, JSON e criação manual. Não há `camera`, `image_picker`
ou galeria. O `AGENTS.md` §10 prevê imagens e câmera no fluxo ideal, e a
auditoria fechou o escopo em fases:

- **P1.0:** PDF/JSON/manual, parser, gabarito e revisão;
- **P1.1:** câmera e galeria;
- **P1.2:** fila de feedback;
- **P1.3:** validação de campo.

O README anterior prometia “Imagens” e “modo de demonstração”; a promessa foi
removida no Lote 1 porque o caminho não existe. O Web não tem OCR local e
precisa declarar essa limitação antes da seleção.

Evidência detalhada:
[[../../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Área 9 — Importação]]
e [[../../09 - Auditoria/Áreas/13 - OCR Android, PaddleOCR e digitalização|Área 13 — OCR Android]].

## Decisão proposta

1. **Manter câmera/galeria no P1.1**, depois de fechar contratos de domínio,
   publicação e o fluxo PDF confiável. Não é escopo do Lote 1 nem do Lote 2.
2. **Não prometer imagem no README** até a implementação existir. A seção “O que
   ainda não existe” registra a lacuna.
3. **Mobile primeiro:** câmera e galeria no Android/iOS, com múltiplas páginas,
   recorte, confirmação e o mesmo pipeline de layout/parser.
4. **Web:** declarar ausência de OCR antes da seleção; não fingir que a imagem
   foi processada localmente.
5. **Feedback e privacidade:** consentimento separado para texto e imagem,
   retenção definida e nenhum upload sem confirmação.
6. **Aceite:** uma prova real de 80 questões sem instruções como questão,
   revisão humana eficiente e nenhuma métrica de confiança inventada.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Implementar câmera agora | Antecipa UI sobre domínio/publicação ainda instáveis e desvia do fluxo PDF, que é a base. |
| Remover câmera do produto | Contraria o `AGENTS.md` §10 e a necessidade real de digitalizar prova em papel. |
| Só galeria, sem câmera | Reduz o caso de uso principal, que é fotografar a prova. |
| Só Web com OCR remoto | Introduz dependência de servidor, custo e privacidade sem decisão aprovada. |

## Consequências e reversão

**Positivas:** expectativa alinhada ao estado real; foco no PDF antes de ampliar
entrada; privacidade e limitação Web explícitas.

**Negativas:** a importação por foto continua ausente; parte do público que só
tem imagem não é atendida nesta fase.

**Reversão:** a decisão é de escopo, não de arquitetura. Quando P1.1 entrar, o
README e o fluxo de publicação são atualizados; nenhum contrato de dados é
quebrado por adiar.

## Evidências e validação

- `lib/features/publish/publish_page.dart` — entrada por PDF/JSON/manual.
- `pubspec.yaml` — sem `camera` ou `image_picker`.
- `README.md` — imagens listadas em “O que ainda não existe”.
- `AGENTS.md` §10 — fluxo ideal e fases P1.0–P1.3.
- Validação necessária: decisão do responsável sobre prioridade e teste em
  aparelho real antes de prometer a função.
