library DriveSerial;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  System.SysUtils,
  System.Classes,
  System.Win.Registry,
  Winapi.Messages,
  Winapi.Windows;

{$R *.res}
//*****************************************************************************
//                 CONSTANTES E VARIÁVEIS DO SISTEMA
//*****************************************************************************
const
  LEN_BUFFER = 100; //Tamanho do Buffer de recepção de dados.
var
  //Variáveis globais.
  hCom : THANDLE; // Handle para a Porta Serial (identificador).
  ComErro: THANDLE;    //Handle da Porta Serial (API).
  dcb: TDCB;                //Estrutura DCB (API).
  CommTime: COMMTIMEOUTS;   //Timeouts (API).
  COMStatus: DWORD;         //Status do Modem (API).
  Lista: Tstrings;
  BufferRecebe: array [0..LEN_BUFFER] of char;   //Para armazenar a string a ser lida.
  BytesLidos: DWORD; //Para retornar a quantidade de bytes realmente lidos.
  Nome_Portas: array [0..100] of string;

//*****************************************************************************
//                        FUNÇÕES PRINCIPAIS
//*****************************************************************************

//****************************************************************************
//                        Abre uma Porta Serial
//*****************************************************************************
{
Comentários sobre o uso:
*Chamada da função:
var
Porta_COM: string;
Resultado: integer;
Resultado:= AbrirPortaSerial(Porta_COM);
NomePorta := 'COM1';  COM1, COM2...COM9 ou portas virtuais.
*Retorno da função (integer):
1: Abriu a porta corretamente
2: A porta selecionada não existe
3: A porta selecionada está em uso.
}
Function AbrirPortaSerial(NomePorta:String):integer; stdcall; export;
Begin
   hCom := CreateFile(
                      PChar(NomePorta),   //Nome da porta (tipo caracteres).
                      GENERIC_READ or GENERIC_WRITE,   //Para leitura e escrita.
                      0,       //(Zero) Nenhuma outra abertura será permitida.
                      nil,  //Atributos de segurança. (nil) padrão.
                      OPEN_EXISTING,  //Criação ou abertura.
                      0,         //(Zero) Entrada e saída sem overlapped.
                      0    //Atributos e Flags. Deve ser 0 para COM.
                    );

   if hCom = INVALID_HANDLE_VALUE then
        begin
                case GetLastError() of  //Detalha o erro.
                ERROR_FILE_NOT_FOUND:
                result := 2;
	              ERROR_ACCESS_DENIED:
                result := 3;
                end;
        end
   else
       result := 1;
End;
exports AbrirPortaSerial;
//*********************************************************************
//                    CONFIGURA UART.
//*********************************************************************
{
Tabela de Argumentos para velocidade de baud:
1:CBR_110
2:CBR_300
3:CBR_600
4:CBR_1200
5:CBR_2400
6:CBR_4800
7:CBR_9600
8:CBR_14400
9:CBR_19200
10:CBR_38400
11:CBR_57600
12:CBR_115200
13:CBR_128000
14:CBR_256000
Tamanho da Palavra de Transmissão: Geralmente 8 bits.
Tabela de configuração de Paridade:
1:EVENPARITY - Even parity.
2:MARKPARITY - Mark parity.
3:NOPARITY   - No parity.
4:ODDPARITY  - Odd parity.
5:SPACEPARITY- Space parity.
Tabela de configuração de Stop Bit
1:ONESTOPBIT - 1 stop bit.
2:ONE5STOPBITS - 1.5 stop bits.
3:TWOSTOPBITS  - 2 stop bits.

Exemplo de Chamada:
var
Flag_configura: boolean;
...
Flag_configura:=ConfiguraUART(2,8,3,1);
  if (Flag_configura<>false) then
  begin
    WriteLn('A porta foi configurada corretamente.');
  end
  else
  begin
    WriteLn('Erro de configuração.');
  end;
}

Function ConfiguraUART
(bauld:integer; Byte_Size: Byte; Paridade:integer; Stop_bit:integer):boolean; stdcall; export;
begin
   if not GetCommState(hCom, dcb) then  //Obtém a configuração atual.
      result:= false;
      case bauld of
          1:dcb.BaudRate := CBR_110;
          2:dcb.BaudRate := CBR_300;
          3:dcb.BaudRate := CBR_600;
          4:dcb.BaudRate := CBR_1200;
          5:dcb.BaudRate := CBR_2400;
          6:dcb.BaudRate := CBR_4800;
          7:dcb.BaudRate := CBR_9600;
          8:dcb.BaudRate := CBR_14400;
          9:dcb.BaudRate := CBR_19200;
          10:dcb.BaudRate := CBR_38400;
          11:dcb.BaudRate := CBR_57600;
          12:dcb.BaudRate := CBR_115200;
          13:dcb.BaudRate := CBR_128000;
          14:dcb.BaudRate := CBR_256000;
      end;
   dcb.ByteSize := Byte_Size;    //define bits de dados.
      case Paridade of
          1:dcb.Parity := EVENPARITY;
          2:dcb.Parity := MARKPARITY;
          3:dcb.Parity := NOPARITY;
          4:dcb.Parity := ODDPARITY;
          5:dcb.Parity := SPACEPARITY;
      end;
   case Stop_bit of
          1:dcb.StopBits := ONESTOPBIT;
          2:dcb.StopBits := ONE5STOPBITS;
          3:dcb.StopBits := TWOSTOPBITS;
   end;
//   dcb.StopBits := ONESTOPBIT;    //define stop bit.
   dcb.Flags := 0;
   if not SetCommState(hCom, dcb) then  //Define nova configuração.
      result:= false
   else
      result:= true;
end;
exports ConfiguraUART;

//*********************************************************************
//                    FECHA A PORTA SERIAL
//*********************************************************************
{
Comentários sobre o uso:
*Chamada da função:
FecharPorta;
}
procedure FecharPorta; export;
begin
   if hCom <> INVALID_HANDLE_VALUE then   //Se a porta está aberta.
   begin
     CloseHandle(hCom);  //Fecha a porta.
   end;
end;
exports FecharPorta;
//***************************************************************************
//            CONFIGURA OS TIMEOUTS (READ/WRITE) DA PORTA
//***************************************************************************
{
Comentários sobre o uso:
*Chamada da função:
var
Resultado: boolean;
Resultado:= config_porta();
*Retorno da função (boolean):
false(0): Houve erro na configuração.
true(Valor diferente de 0): Os time-outs foram configurados corretamentes.
}
function config_porta():boolean; export;
Var
   CommTimeouts: TCOMMTIMEOUTS;
Begin
   if not GetCommTimeouts(hCom, CommTimeouts) then //Obtém os Timeouts atuais.
       result:= false; //se houve erro.

    //Atribui novos valores.
   CommTimeouts.ReadIntervalTimeout := 2;
   CommTimeouts.ReadTotalTimeoutMultiplier := 0;
   CommTimeouts.ReadTotalTimeoutConstant := 2;
   CommTimeouts.WriteTotalTimeoutMultiplier := 5;
   CommTimeouts.WriteTotalTimeoutConstant := 5;

   if not SetCommTimeouts(hCom, CommTimeouts) then //Configura Timeouts.
      result:= false  //se houve erro.
   else
      result:= true;
End;
exports config_porta;
//**********************************************************************
//                        LE PORTA SERIAL
//***********************************************************************
{
TIPOS DE CHAMADAS:
1)LÊ 1 BYTE DA PORTA SERIAL
le_porta;
        if  (BytesLidos<>0) then
        begin
        WriteLn('Recebido Byte: '+BufferRecebe[0]);
        WriteLn('Bytes para ler:', inttostr(BytesLidos));
        BytesLidos:=0;
        end;

2)LÊ 1 BYTE DA PORTA SERIAL EM FORMATO NUMÉRICO
var
Valor Recebido: integer;
...
le_porta;
        if  (BytesLidos<>0) then
        begin
        Valor_Recebido:= int8(BufferRecebe[0]);
        WriteLn('Valor Recebido:', inttostr(Valor_Recebido));
        BytesLidos:=0;
        end;

3)PROCEDIMENTO PARA CHAMADA USANDO INTERRUPÇÃO DO COMPOMENTE TTIMER
procedure TForm1.Timer1Timer(Sender: TObject);
begin
le_porta;
        if  (BytesLidos<>0) then
        begin
        label5.Caption:=BufferRecebe[0];
        label7.Caption:=inttostr(BytesLidos);
        BytesLidos:=0;
        end;
end;
}
procedure le_porta; export;
Begin
   //Lê uma String da Porta Serial e aloca em BufferRecebe.
   ReadFile( hCom, BufferRecebe, LEN_BUFFER, BytesLidos, nil);
End;
exports le_porta;

function recebe_dado(count:integer): char; stdcall; export;
begin
  result:= BufferRecebe[count];
end;
exports recebe_dado;

function bytes_ler(): integer; export;
begin
  result:= BytesLidos;
end;
exports bytes_ler;

procedure reset_buffer(); export;
begin
  BytesLidos:=0;
end;
exports reset_buffer;

//***************************************************************************
//               ENVIAR UMA STRING PELA PORTA SERIAL
//***************************************************************************
{
A FUNÇÃO RETORNA A QUANTIDADE DE BYTES ESCRITOS EM UMA DWORD
BufferEnvia --> Para armazenar a string a ser enviada.

EXEMPLO DE CHAMADA
Var
Envia_string: AnsiString;
Bytes_enviados_flag: integer;
...
Envia_string:='Teste';
Bytes_enviados_flag:=envia_serial(Envia_string);
WriteLn('Numero de Bytes Enviados:', inttostr(Bytes_enviados_flag));
}
function envia_serial(var BufferEnvia: AnsiString):DWORD; export;
Var
   BytesEscritos: DWORD;  //Para retornar a quantidade de bytes realmente escritos.
   TamaString: integer;    //Para calcular o tamanho da String.
begin
   TamaString := Length(BufferEnvia); //Obtém o tamanho da string a ser enviada.
   WriteFile( hCom, PChar(BufferEnvia)^, TamaString, BytesEscritos, nil);
   result:=TamaString;
end;


//*********************************************************************
//        TRANSMITE 1 BYTE PELA PORTA SERIAL
//*********************************************************************
{  Esta função e usada para transmitir um caracter através da linha TXD.
Ela coloca o caracter a ser transmitido a frente de quaisquer caracteres
existentes no buffer de transmissão. Se houver sucesso na transmissão,
TransmitCommChar() retorna um valor diferente de zero, caso contrário,
retorna um valor igual a zero.
  Ela é útil também para enviar caracter de interrupção de transmissão
(como um CTRL+C) diretamente para a porta serial.
EXEMPLO DE CHAMADA:
   var
   Envia: AnsiChar;
   Flag_envia: boolean
   ....
   Envia:='T';         //Tem  que declarar como AnsiChar Antes, não pode
                       //passar direto entre aspas
   ... ou
   Envia:=#65;         Para enviar em formato numérico
   ...
   TX_catacter(Envia);
   if (Flag_envia<>false) then
  begin
    WriteLn('O caractere foi enviado cerretamente.');
  end
  else
  begin
    WriteLn('O caractere não foi enviado.');
  end;
}

function TX_catacter(var tx:AnsiChar):boolean; export;
begin
result:=TransmitCommChar(hCom, tx); //Transmite o caracter 'A' pela porta Serial.
end;
exports TX_catacter;

//*******************************  FIM  ***************************************
begin
end.
