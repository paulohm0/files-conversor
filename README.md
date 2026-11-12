# <p align="center"> Conversor de Arquivos

Aplicativo desktop para Windows que converte imagens, PDFs, documentos, planilhas e apresentações com um clique: arraste os arquivos, escolha o formato e pronto.

O projeto nasceu como um script em PowerShell + Windows Forms (~2000 linhas) que eu usava no dia a dia. A ideia aqui foi reescrever tudo em Flutter Desktop com Clean Architecture, mantendo exatamente o mesmo comportamento do script (que serviu de especificação) e corrigindo de quebra uma falha antiga dele no cancelamento.

## > Funcionalidades

- Arrastar e soltar arquivos ou pastas (pastas são expandidas só no primeiro nível), colar do Explorer com Ctrl+V ou escolher pelo diálogo
- Botões de formato que aparecem conforme os arquivos da lista, mostrando só os formatos comuns a todos; um clique converte
- Conversões com fallback automático entre motores:

| Entrada | Saída | Motor, em ordem de tentativa |
|---|---|---|
| Imagens (PNG, JPG, JPEG, JFIF, BMP, GIF, TIFF, ICO, WEBP, HEIC, HEIF) | PNG, JPG, BMP, GIF, TIFF, ICO, PDF | Nativo (Dart) |
| PDF | PNG, JPG (uma imagem por página) | Nativo (PDFium) |
| PDF | DOCX | Acrobat, Word, pdf2docx, LibreOffice |
| PDF | XLSX, PPTX | Somente Acrobat Pro/Standard |
| Documentos (DOC, DOCX, DOCM, DOTX, ODT, RTF, TXT, MD, HTM, HTML) | PDF, DOCX, DOC, ODT, RTF, TXT | Word, LibreOffice |
| Planilhas (XLSX, XLS, XLSM, ODS, CSV) | PDF, XLSX, ODS, CSV | Excel, LibreOffice |
| Slides (PPTX, PPT, PPTM, PPSX, PPS, ODP) | PDF, PPTX, ODP | PowerPoint, LibreOffice |

- Imagens: rotação EXIF aplicada, fundo branco em JPG/BMP/PDF quando há transparência, ICO com 7 tamanhos (256 a 16)
- Imagens para PDF em A4 (retrato ou paisagem conforme a imagem, margem de 1 cm), com opção de juntar tudo em um só PDF
- Nunca sobrescreve: gera `nome (1).ext`, `nome (2).ext`...
- Original vai para a **Lixeira** (nunca exclusão permanente) só se a opção estiver marcada e a saída existir e não estiver vazia
- Histórico na lista: itens convertidos podem ser selecionados e reconvertidos
- Atalho "Enviar para" do Explorer sempre instalado: o app confere a cada abertura e recria se faltar ou se o `.exe` mudar de pasta (os arquivos chegam por `main(args)`)
- "Testar conversões" (ícone no canto superior direito): cria arquivos de exemplo, testa cada motor isoladamente e mostra um resumo em linguagem simples ("Imagens: funcionando", "Adobe Acrobat: não funciona neste computador" com o motivo); o relatório técnico `.txt`/`.csv` fica disponível em "Ver relatório completo"
- Tema claro e escuro seguindo o sistema, interface em português

**Atalhos:** Ctrl+O adiciona · Ctrl+V cola · Ctrl+A seleciona tudo · Delete remove · Enter repete o último formato · Esc cancela ou limpa a seleção

## > Arquitetura

Clean Architecture enxuta, organizada por feature:

```
lib/
  core/                  # Result, erros, cancelamento, caminhos, DI (get_it), tema
  features/
    conversion/
      domain/            # Entidades, contratos (ConversionEngine, EngineDetector...), EngineChain, casos de uso
      data/              # Motores, codec de imagens, ponte PowerShell, registro/Lixeira/Explorer do Windows
      presentation/      # Cubits, tela principal e widgets
    settings/            # Opções persistidas (SettingsCubit)
    integration/         # Atalho "Enviar para" sempre instalado
    diagnostics/         # Autoteste (DiagnosticsCubit)
  main.dart
assets/
  office_bridge.ps1      # Ponte COM: Word, Excel, PowerPoint, Acrobat, HEIC (WIC) e "Enviar para"
```

## > Tech Stack

- Flutter / Dart (Windows Desktop)
- flutter_bloc (Cubit) · equatable
- get_it
- image (em isolate) · pdf · pdfrx (PDFium)
- desktop_drop · file_selector · super_clipboard
- shared_preferences · window_manager
- win32 · ffi (registro e Lixeira do Windows)
- PowerShell 5.1 + COM (Office e Acrobat)

**Testes:** flutter_test · bloc_test · mocktail

## > Padrões e decisões técnicas

- **Strategy**: cada motor implementa `ConversionEngine` (`canConvert`, `convert`): `ImageEngine`, `ImagePdfEngine`, `PdfRasterEngine`, `LibreOfficeEngine`, `Pdf2DocxEngine`, `WordEngine`, `ExcelEngine`, `PowerPointEngine`, `AcrobatEngine`
- **Chain of Responsibility**: `EngineChain` tenta os motores na ordem; se um falha, apaga o arquivo parcial e passa para o próximo; se todos falham, junta os erros numa mensagem só
- **`OutputAllocator`**: reserva os caminhos de saída de cada arquivo e sabe apagar tudo o que gerou, o que corrige a falha do script original (ao cancelar PDF → imagem, as páginas já gravadas agora são apagadas)
- **Repository**: `EngineDetector`, `RecycleBin`, `ShellIntegration`, `SettingsRepository` atrás de interfaces, testados com fakes
- **`ConvertFiles` como `Stream` de eventos** (status, log, progresso, motor desativado, fim): o Cubit só traduz eventos em estado, sem regra de negócio
- **Ponte PowerShell em vez de COM direto em Dart**: um `powershell.exe -STA` fica vivo durante o lote (reaproveitando a instância do Office) e conversa por uma caixa de mensagens em arquivos (`req_N.json` / `resp_N.json`, gravados como `.tmp` e renomeados). O stdin foi descartado como canal porque, quando o PowerShell 5.1 é iniciado pelo Dart, ele só recebe a primeira linha. A ponte também se encerra sozinha se o app fechar
- **Fechamento seguro do Office**: Word, Excel, PowerPoint e Acrobat abrem invisíveis, somente leitura e com macros desativadas, e só são fechados se o usuário não tiver documentos abertos neles. No caminho foi corrigido um defeito herdado do script: `Word.Quit(0)` falhava em silêncio (o parâmetro é por referência no COM) e deixava um `WINWORD.EXE` aberto a cada lote
- **Acrobat sem licença**: na primeira falha de automação o motor é desativado na sessão e o usuário é avisado; a conversão segue com o próximo motor
- **Trabalho pesado fora da UI**: decodificação/codificação de imagem e montagem do PDF em `Isolate.run`, Office e LibreOffice em processos separados
- **Lixeira via `SHFileOperation` com `FOF_ALLOWUNDO`**: o arquivo é sempre recuperável
- **Sem rede**: o app não faz nenhuma requisição; o PDFium é empacotado no build

## > IA no fluxo de desenvolvimento

O projeto foi desenvolvido com apoio do Claude Code.

- O script PowerShell original foi usado como especificação: cada regra (nomes de saída, Lixeira, ordem dos motores, fechamento do Office) foi portada e coberta por teste
- A ponte COM foi testada diretamente contra o Word, Excel e PowerPoint instalados antes de ser ligada ao app
- Todo código gerado foi **revisado e entendido** antes de ser incorporado, e as decisões de arquitetura foram definidas por mim

## > Testes

Cobertura nas três camadas:
- **Domínio**: `EngineChain` (fallback, limpeza de parcial, erros agrupados, cancelamento, motor desativado), `ConvertFiles` (nunca sobrescrever, pular mesmo formato, Lixeira só após sucesso, juntar imagens, cancelamento apagando páginas), `GetAvailableTargets`
- **Dados**: codec de imagens (fundo branco, transparência, ICO, EXIF, geometria A4), `LibreOfficeEngine` com `ProcessRunner` mockado, `WindowsEngineDetector` com registro falso
- **Apresentação**: Cubits com `bloc_test` e testes de widget da tela principal (área de soltar, diálogo de confirmação com aviso da Lixeira, registro)

- **Integração** (`test/integration`, tag `office`): a ponte PowerShell contra o Office instalado, pulando o que não existir na máquina

```bash
flutter test
```

O próprio executável também roda o autoteste completo sem abrir a janela (útil para validar uma máquina nova):

```bash
conversor_arquivos.exe --autoteste C:\pasta\do\relatorio
```

## > Como rodar o projeto

Pré-requisitos: Flutter SDK, Visual Studio 2022 com "Desktop development with C++" e o **Modo de Desenvolvedor do Windows ativado** (os plugins Flutter usam links simbólicos).

```bash
git clone https://github.com/paulohm0/files-conversor.git
cd files-conversor
flutter pub get
flutter run -d windows
```

Para gerar o executável (roda análise, testes e build release):

```bash
build.bat
```

O `.exe` fica em `build\windows\x64\runner\Release\`. Para distribuir, copie a pasta `Release` inteira.

**Motores opcionais:** Microsoft Office e Adobe Acrobat Pro/Standard são detectados pelo registro. O LibreOffice pode estar instalado ou numa pasta `engines\LibreOffice` ao lado do `.exe`; o `pdf2docx` pode estar no PATH ou em `engines\pdf2docx\`.

## > Status do projeto

- ✅ Conversões nativas de imagem e imagem → PDF
- ✅ Ponte COM com Word, Excel e PowerPoint
- ✅ Cadeia de fallback, Lixeira, cancelamento, "Enviar para" e autoteste
- ✅ Testes unitários, de widget e de integração com o Office
- ✅ Build release validado ponta a ponta pelo autoteste (imagens, PDF → imagem, Word, Excel, PowerPoint, juntar PDF e Lixeira)
- ⏳ Validação com Acrobat Pro/Standard licenciado, LibreOffice e pdf2docx instalados

## > Habilidades Testadas

- ✅ Clean Architecture por feature (domain / data / presentation)
- ✅ Padrões Strategy, Chain of Responsibility e Repository
- ✅ Gerenciamento de estado com Cubit (flutter_bloc) e estados imutáveis
- ✅ Injeção de dependência (get_it)
- ✅ Flutter Desktop no Windows (drag and drop, clipboard, janela, FFI com win32)
- ✅ Isolates para processamento pesado
- ✅ Integração com processos externos e automação COM via PowerShell
- ✅ Testes unitários, de Cubit e de widget
