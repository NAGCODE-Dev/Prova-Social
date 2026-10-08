Prova Social

Aplicativo para digitalização, resolução e acompanhamento de provas, desenvolvido em Flutter.

O projeto permite importar provas a partir de arquivos PDF e imagens, processá-las localmente, organizar questões e acompanhar tentativas e resultados.

<p align="center">
  <a href="https://github.com/NAGCODE-Dev/Prova-Social/actions/workflows/flutter-ci.yml"><img src="https://github.com/NAGCODE-Dev/Prova-Social/actions/workflows/flutter-ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Flutter-3.47.6-02569B?logo=flutter&logoColor=white" alt="Flutter 3.47.6">
  <img src="https://img.shields.io/badge/version-0.7.0-16A36A" alt="Version 0.7.0">
</p>Funcionalidades

- Autenticação com Supabase
- Feed, busca e biblioteca de provas
- Favoritos por usuário
- Perfil
- Resolução de provas
- Focus Mode
- Cronômetro
- Mapa de questões
- Revisão antes da entrega
- Importação de PDFs
- Extração de texto
- OCR local no Android
- Identificação automática de questões e alternativas
- Revisão manual do conteúdo importado
- Armazenamento de provas em JSON compactado com GZip
- Deduplicação de imagens por SHA-256
- Salvamento local das respostas durante a tentativa
- Restauração de tentativas
- Sincronização de resultados
- Tema claro e escuro
- Suporte a redução de movimento
- Android e Web

Processamento de provas

O processamento ocorre localmente sempre que possível.

PDF ou imagem
      |
      v
Extração de texto / OCR
      |
      v
Identificação das questões
      |
      v
Revisão do conteúdo
      |
      v
JSON estruturado + GZip
      |
      v
Cache / sincronização
      |
      v
Resolução

No Android, páginas sem camada de texto podem ser renderizadas e processadas por OCR. O importador atualmente trabalha com questões numeradas e alternativas de A a E.

Arquitetura

lib/
├── core/
│   ├── backend/
│   ├── theme/
│   └── shared/
├── domain/
├── features/
└── ...

packages/
└── paddleocr_android/

supabase/
├── migrations/
├── functions/
└── ...

test/
qa/
tool/

Tecnologias

Área| Tecnologia
Aplicativo| Flutter / Dart
Backend| Supabase
Autenticação| Supabase Auth
OCR| Google ML Kit / PaddleOCR
PDF| pdfrx
Armazenamento local| SharedPreferences / arquivos
Web| Flutter Web
Hospedagem Web| Cloudflare Pages
CI/CD| GitHub Actions
Distribuição Android| GitHub Releases

Desenvolvimento

Requisitos

- Flutter 3.47.6
- Dart compatível com Flutter 3.47
- Android SDK
- Node.js 22
- Git

Instalação

```sh
git clone https://github.com/NAGCODE-Dev/Prova-Social.git
cd Prova-Social
flutter pub get
```

Preparar e validar o módulo Android local:

```sh
flutter create . --platforms=android --project-name=prova_social --org=dev.nagcode --no-pub
rm -f test/widget_test.dart
flutter pub get
cd android
./gradlew :paddleocr_android:dependencies --configuration releaseRuntimeClasspath
```

Execute o Gradle pela pasta `android/` gerada na raiz. `packages/paddleocr_android/android`
é um módulo Flutter, não um projeto Gradle independente: ele recebe os plugins
Android do projeto hospedeiro. Executar Gradle diretamente nesse subdiretório
produz `Plugin with id 'com.android.library' not found`. Não fixe nem rebaixe a
versão do Gradle isoladamente; use o wrapper gerado pela versão Flutter definida
no workflow.

Executar

```sh
cp .env.supabase.json.example .env.supabase.json
# Edite o arquivo local com SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY do projeto.
./tool/flutter_with_supabase.sh run
```

O arquivo `.env.supabase.json` é ignorado pelo Git. O wrapper aceita comandos
Flutter e injeta a configuração local em cada execução/build:

```sh
./tool/flutter_with_supabase.sh run -d chrome
./tool/flutter_with_supabase.sh build apk --debug
```

Este checkout não versiona a plataforma Web. Para executá-lo no Chrome pela
primeira vez, gere os arquivos de plataforma e aplique a preparação de marca:

```sh
flutter create . --platforms=web --project-name=prova_social --org=dev.nagcode --no-pub
python3 tool/prepare_web.py
./tool/flutter_with_supabase.sh run -d chrome
```

Testes

flutter analyze
flutter test

Para verificar formatação:

dart format --output=none --set-exit-if-changed lib test tool packages

Configuração

O app recebe `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` como configuração
pública de cliente em tempo de build, usando `String.fromEnvironment` e
`--dart-define-from-file`. A publishable key pode ser incluída no APK e no Web;
Auth, RLS e grants do banco continuam responsáveis pela autorização.

Para desenvolvimento local, copie `.env.supabase.json.example` para
`.env.supabase.json` e preencha os valores em Supabase → Connect. O arquivo
local é ignorado pelo Git e o wrapper valida os campos sem exibir seus valores.
Use o wrapper para `run` e builds locais; `flutter run` diretamente não carrega
a configuração local.

No GitHub Actions, configure os repository secrets `SUPABASE_URL` e
`SUPABASE_PUBLISHABLE_KEY`. O workflow gera um JSON temporário fora do checkout
e o injeta em builds Web e Android (universal e por ABI). O APK de release não
depende de arquivos presentes no computador do desenvolvedor. Builds Web de
QA usam placeholders e não autenticam no projeto real.

São valores públicos de cliente somente `SUPABASE_URL` e
`SUPABASE_PUBLISHABLE_KEY` (preferencialmente prefixo `sb_publishable_`). Nunca
coloque `SUPABASE_SECRET_KEY`, `service_role`, senha do banco, segredo do Google
OAuth ou token administrativo no app, em arquivo versionado ou em logs. Uma
chave `anon` JWT legada é aceita para compatibilidade, mas deve ser migrada para
publishable key.

CI/CD

O GitHub Actions executa automaticamente as verificações do projeto.

A pipeline inclui:

- análise estática;
- testes Flutter;
- verificações de QA;
- build Web;
- browser QA;
- validação dos arquivos gerados;
- APK universal, APKs por arquitetura e pacote Flutter Web anexados à Release da tag;
- deploy para Cloudflare Pages quando os secrets de produção estiverem configurados;
- publicação dos APKs em GitHub Releases.

Se `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `CLOUDFLARE_API_TOKEN` ou
`CLOUDFLARE_ACCOUNT_ID` não estiver configurado, o deploy Web é explicitamente
ignorado; os gates de QA e o build Web de validação continuam sendo executados.

Pushes para "main" executam o fluxo Web.

Tags no formato "v*" iniciam no GitHub Actions o QA completo, os builds Android
assinados e o build Flutter Web. Os APKs e um ZIP da versão Web são anexados à
Release; nenhum build de distribuição depende do Codemagic ou de um computador
local. O deploy Cloudflare permanece opcional e roda no push de `main` quando
suas credenciais estiverem configuradas.

Versionamento

Versão atual:

0.7.0+10

Releases utilizam tags seguindo o padrão:

v0.7.0
v0.8.0
v1.0.0

Estrutura do projeto

.
├── lib/                 Código da aplicação
├── packages/            Pacotes locais
├── assets/              Recursos estáticos
├── supabase/            Banco e funções do Supabase
├── test/                Testes
├── qa/                  Scripts de QA
├── tool/                Ferramentas auxiliares
├── android/             Projeto Android gerado/configurado
├── web/                 Projeto Web
├── .github/workflows/   CI/CD
└── pubspec.yaml         Dependências e configuração Flutter

Estado do projeto

O Prova Social está em desenvolvimento ativo. A versão atual concentra-se na importação e resolução de provas, processamento local, persistência de tentativas e infraestrutura de build e distribuição.

Segurança

Não adicione ao repositório:

- chaves privadas;
- tokens;
- senhas;
- arquivos ".env" contendo segredos;
- keystores;
- credenciais do Supabase;
- credenciais do Cloudflare.
