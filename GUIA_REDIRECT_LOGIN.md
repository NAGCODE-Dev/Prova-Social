# Retorno do e-mail para o aplicativo

O aplicativo usa este endereço de retorno:

`provasocial://login-callback`

No painel do Supabase:

1. Abra **Authentication → URL Configuration**.
2. Em **Redirect URLs**, adicione exatamente `provasocial://login-callback`.
3. Salve a configuração.
4. Em **Authentication → Email Templates**, traduza o texto do e-mail se desejar.

O `Site URL` não deve permanecer como `http://localhost:3000` em produção.
Use o endereço público do site do Prova Social como Site URL. O endereço
personalizado acima continua necessário para o retorno ao APK.

Depois de confirmar o e-mail, o Android reconhece o esquema `provasocial` e
abre o aplicativo, onde o Supabase conclui a sessão automaticamente.
