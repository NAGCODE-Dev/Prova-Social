# Prova Social — backend e arquivos no Supabase

Esta versão não utiliza Cloudflare R2 nem exige variável adicional no Codemagic.

## Aplicar pelo Acode

```sh
cd ~/Prova-Social-repo
mkdir -p ~/prova-social-supabase
unzip -o /storage/emulated/0/Download/Prova-Social-digitalizacao-eficiente-v1.zip \
  -d ~/prova-social-supabase
cp -r ~/prova-social-supabase/. ~/Prova-Social-repo/
```

## Enviar ao GitHub

```sh
cd ~/Prova-Social-repo
git add .
git commit -m "Adicionar backend e digitalização eficiente de provas"
git pull --rebase origin main
git push origin main
```

Não crie `R2_API_URL` no Codemagic. O aplicativo usa o projeto Supabase já
configurado e o bucket privado `exam-content`. O pacote inclui JSON em GZip,
imagens separadas, deduplicação por SHA-256 e carregamento sob demanda.
