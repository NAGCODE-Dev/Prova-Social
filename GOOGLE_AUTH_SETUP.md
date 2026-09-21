# Login Google — configuração externa

O aplicativo não contém Client Secret. O Google autentica o usuário, o
Supabase valida o retorno e o Flutter recebe apenas a sessão.

## 1. Google Cloud Console

1. Crie ou selecione o projeto do Prova Social.
2. Configure a tela de consentimento OAuth.
3. Crie uma credencial **OAuth Client ID — Web application**.
4. Em **Authorized redirect URIs**, adicione exatamente a callback exibida em
   Supabase Dashboard → Authentication → Providers → Google. O formato costuma
   ser `https://SEU-PROJETO.supabase.co/auth/v1/callback`.
5. Copie o Client ID e o Client Secret.

## 2. Supabase

1. Authentication → Providers → Google.
2. Ative o provedor e informe Client ID e Client Secret.
3. Em URL Configuration, defina:
   - Site URL: `https://prova-social.pages.dev/app/`
   - Redirect URL Web: `https://prova-social.pages.dev/app/`
   - Redirect URL Android: `provasocial://login-callback`

## 3. Codemagic

Crie variáveis protegidas no workflow:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Não use `service_role`, secret key nem o Client Secret do Google no Flutter.

## 4. Banco

Execute primeiro `supabase/migrations/202609210001_core.sql`. Depois aplique as
migrações opcionais de mídia e recursos sociais, já adaptadas ao schema atual.
