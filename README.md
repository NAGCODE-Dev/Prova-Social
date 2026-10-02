Prova Social

Aplicativo para digitalização, resolução e acompanhamento de provas, desenvolvido em Flutter.

O projeto permite importar provas a partir de arquivos PDF e imagens, processá-las localmente, organizar questões e acompanhar tentativas e resultados.

<p align="center">
  <a href="https://github.com/NAGCODE-Dev/Prova-Social/actions/workflows/flutter-ci.yml"><img src="https://github.com/NAGCODE-Dev/Prova-Social/actions/workflows/flutter-ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Flutter-3.47.0-02569B?logo=flutter&logoColor=white" alt="Flutter 3.47.0">
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

- Flutter 3.47.0
- Dart compatível com Flutter 3.47
- Android SDK
- Node.js 22
- Git

Instalação

git clone https://github.com/NAGCODE-Dev/Prova-Social.git
cd Prova-Social
flutter pub get

Executar

flutter run

Para executar no navegador:

flutter run -d chrome

Testes

flutter analyze
flutter test

Para verificar formatação:

dart format --output=none --set-exit-if-changed lib test tool packages

Configuração

Informações sensíveis não devem ser armazenadas no repositório.

A aplicação utiliza variáveis como:

SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY

Os valores utilizados nos builds de produção são fornecidos pelo GitHub Actions através de secrets.

CI/CD

O GitHub Actions executa automaticamente as verificações do projeto.

A pipeline inclui:

- análise estática;
- testes Flutter;
- verificações de QA;
- build Web;
- browser QA;
- validação dos arquivos gerados;
- deploy para Cloudflare Pages;
- build Android;
- publicação dos APKs em GitHub Releases.

Pushes para "main" executam o fluxo Web.

Tags no formato "v*" iniciam o fluxo de release Android.

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
