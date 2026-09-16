# Prova Social — Flutter

Base Flutter do aplicativo Prova Social. O MVP inclui feed responsivo, busca, filtros, favoritos temporários, resolução de prova, cronômetro, mapa de questões, revisão, correção automática e resultado copiável em JSON.

## Abrir no Firebase Studio/IDX, Android Studio ou VS Code

Na raiz desta pasta, execute:

```bash
flutter create . --platforms=android,web
flutter pub get
flutter test
flutter run
```

`flutter create .` completa somente os arquivos nativos gerados pelo SDK; o código da aplicação em `lib/` é preservado.

## Gerar APK no Codemagic

O arquivo `codemagic.yaml` configura uma compilação automática que instala o Flutter, completa a estrutura Android, verifica o código, executa os testes e gera `app-debug.apk`.

No Codemagic:

1. conecte sua conta do GitHub;
2. adicione o repositório `NAGCODE-Dev/Prova-Social`;
3. selecione a configuração por `codemagic.yaml`;
4. execute o fluxo **Prova Social — APK Android**;
5. baixe o APK na seção **Artifacts** após a compilação.

## Estrutura

- `lib/core`: tema e recursos compartilhados
- `lib/domain`: modelos e regras da aplicação
- `lib/data`: dados demonstrativos; será substituído por repositórios Supabase
- `lib/features`: páginas agrupadas por funcionalidade
- `test`: testes das regras principais

## Próxima etapa planejada

1. Adicionar configuração por variáveis de ambiente
2. Integrar Supabase Auth e banco de dados
3. Persistir provas, tentativas, favoritos e perfis
4. Criar importação validada de provas por JSON
5. Adicionar upload e processamento de PDF como etapa separada

Nenhuma chave ou segredo deve ser incluído no repositório.
