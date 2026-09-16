# Prova Social — Flutter

Rede de questões e provas construída em Flutter, com identidade Study Surface,
autenticação e backend Supabase, distribuição Android/Web e atualização por
GitHub Releases.

## O que esta versão inclui

- login e criação de conta com Supabase Auth;
- feed, busca, biblioteca, perfil e publicação responsivos;
- **Focus Mode** para resolver provas sem distrações;
- cronômetro isolado, mapa de questões, revisão e entrega consciente;
- fluxo de importação de PDF: seleção, identificação e preparação;
- pacote digital em JSON GZip e imagens separadas com deduplicação SHA-256;
- skeletons contextuais, modo escuro e redução de movimento;
- atualização pelo GitHub e builds Android/Web pelo Codemagic.

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
4. execute o fluxo **Prova Social - Android e Web**;
5. baixe o APK ou os arquivos web em **Artifacts** após a compilação.

## Estrutura

- `lib/core`: tema, backend, atualização e componentes compartilhados
- `lib/domain`: modelos e regras da aplicação
- `lib/data`: dados demonstrativos e integração progressiva com Supabase
- `lib/features`: páginas agrupadas por funcionalidade
- `supabase`: esquema, políticas e funções de armazenamento
- `test`: testes das regras principais

## Estado do PDF

As telas de seleção e identificação estão prontas. A extração automática/OCR
ainda precisa ser conectada; a interface informa isso claramente e não simula
resultados. O PDF original não é distribuído aos alunos.

Nenhuma chave ou segredo deve ser incluído no repositório.
