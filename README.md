# Identificador Windows

Painel de identificação de hardware e sistema em um único arquivo `IDENTIFICADOR.bat`, com PowerShell integrado. Organiza as informações em duas colunas e destaca em verde os campos usados no inventário, facilitando fotografar a tela e preencher uma planilha.

## Como usar

1. Baixe `IDENTIFICADOR.bat` pelo botão de download do arquivo no GitHub.
2. No Windows, abra o arquivo por duplo clique.
3. Confirme a solicitação de administrador.

Utiliza Windows PowerShell 5.1 e consultas locais via CIM. O ajuste automático de fonte foi desenvolvido para o CMD clássico; no Windows Terminal, ajuste a fonte pelo próprio terminal.

## Informações exibidas

- Computador, usuário, conta de execução e adaptadores de rede, incluindo IPv4, gateway e MAC.
- Sistema operacional, versão, build, arquitetura e última inicialização.
- Placa-mãe e BIOS.
- Processador, núcleos, threads, uso informado pelo Windows e frequência máxima.
- Memória RAM total, módulos e memória disponível.
- Discos físicos, capacidade, tipo SSD/HD, interface e espaço das unidades locais.

O tipo SSD/HD usa a informação do Windows, associada por número de série único e capacidade compatível. Se não houver confirmação, exibe `Nao identificado`.

## Controles

| Tecla | Ação |
| --- | --- |
| A | Atualizar informações |
| F | Reajustar fonte e janela automaticamente |
| + / - | Aumentar ou diminuir a fonte |
| N / P ou setas | Trocar página, quando necessário |
| X | Sair |

Não exporta TXT, não altera serviços e não envia as informações coletadas para a internet. Os dados aparecem apenas no painel. A ferramenta ajusta a apresentação da janela do console.

## Validação

O painel foi testado manualmente pelo autor durante o desenvolvimento. A identificação SSD/HD pode depender do driver e do controlador de armazenamento; não há testes automatizados neste repositório.
