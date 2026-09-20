# Matriz de compatibilidade — Prova Social 0.5.0

Versões verificadas nos `pubspec` publicados em 17/09/2026.

| Dependência direta | Versão | Restrição compartilhada relevante |
| --- | ---: | --- |
| `file_picker` | 13.1.0 | `windows_file_picker ^2.0.0` → `win32 ^6.3.0` |
| `package_info_plus` | 10.2.1 | `win32 ^6.0.1`, `ffi ^2.2.0`, `http ^1.6.0` |
| `pdfrx` | 2.6.1 | Dart `^3.13.0`, Flutter `>=3.47.0`, `crypto ^3.0.7` |
| `image` | 4.10.1 | `archive ^4.0.9` |
| `google_mlkit_text_recognition` | 0.17.1 | Dart `^3.12.0`, Flutter `>=3.44.0` |
| `supabase_flutter` | 2.10.0 | `http <2.0.0`, `crypto ^3.0.2`, `web <2.0.0` |

Resolução fixada:

- `win32`: intervalo comum `>=6.3.0 <7.0.0`;
- `ffi`: `>=2.2.0 <3.0.0`;
- `http`: `1.6.0`;
- `web`: `>=1.1.1 <2.0.0`;
- `archive`: `4.0.9`;
- `crypto`: `3.0.7`;
- Dart mínimo: `3.13.0`;
- Flutter mínimo: `3.47.0`.

Não execute `flutter pub upgrade --major-versions` no pipeline. Alterações de
dependências devem atualizar esta matriz e passar por `flutter pub get`, análise
e testes no Codemagic.
