codeunit 60101 "DiarioRecepcionEfectivo"
{
    Permissions = TableData Customer = rimd,
                  TableData "Gen. Journal Line" = rimd,
                  TableData "General Ledger Setup" = rimd,
                  TableData "Bank Account" = rm;


    var
        ConfContab: Record "General Ledger Setup";


        BcoACH: Record DSNBancosACH;

        BankAccount: Record "Bank Account";
        BankAccount2: Record "Bank Account";
        GenJnlLine: Record "Gen. Journal Line";
        CompanyInfo: Record "Company Information";

        Customer: Record Customer;
        CustomerBank: Record "Customer Bank Account";

        DocumentServiceManagement: Codeunit "Document Service Management";
        StreamIn: InStream;
        StreamOut: OutStream;
        Lin_Body: Text[320];

        Lin_Body2: Text[400];
        CERO: Text[100];
        Blanco: Text[30];
        Window: Dialog;
        Text001: Label 'Generating file #1########## @2@@@@@@@@@@@@@';
        CounterTotal: Integer;
        Counter: Integer;
        Err002: Label 'You must specify the Bank as balance account';
        NombreArchivo: Text;
        NombreArchivo2: Text;
        TotalGeneral: Decimal;
        Tracenumber: Text[30];
        FechaTrans: Date;

        ExportAmount: Decimal;
        Err003: Label 'The date in the journal should be the same or later than today, please check';
        PrimeraVez: Boolean;
        SecuenciaTrans: Code[10];
        tmpBlob: Codeunit "Temp Blob";
        CRLF: Text[2];
        AnsiStr: Text[250];
        AsciiStr: Text[250];



    [Scope('Cloud')]
    procedure FormatoPagoClientes(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        Err001: Label 'The bank account must be the same in all the lines, please correct it';
        GenJnlLine: Record "Gen. Journal Line";
        CustomerBank: Record "Customer Bank Account";
        Customer: Record Customer;
        FirstTime: Boolean;
        FirstTime2: Boolean;
        BancoAnt: Code[20];
        TAB: Char;
        TextMes: Code[3];
        NoLin: Integer;
        CodBco: Code[20];
        ExportAmount: Decimal;
        TraceNumber: Code[30];
        SettleDate: Date;
        Lin_Detail: Text[1024];
        Seq: Integer;
    begin
        //Verifico que todas las lineas del diario tengan el mismo banco
        //elimina();


        FirstTime := true;
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);

        GenJnlLine.FindSet;
        repeat
            if FirstTime then begin
                FirstTime := false;
                BancoAnt := GenJnlLine."Bal. Account No.";
                BankAccount.Get(BancoAnt);
            end;
            if BancoAnt <> GenJnlLine."Bal. Account No." then
                Error(Err001);
            GenJnlLine.Testfield("Document No.");
        until GenJnlLine.Next = 0;

        BankAccount.TestField(DSNFormato); //Verifico que el campo este lleno

        BcoACH.get(BankAccount.DSNFormato); //Busco en ACH el identificador del banco
        BcoACH.TestField("Codigo Banco"); //Verifico que este lleno


        case BcoACH."Codigo Banco" of
            'BPD':
                FormatoBPD(CodDiario, SeccDiario);
            'BHD':
                FormatoBHD(CodDiario, SeccDiario);
            'SCB':
                FormatoSCA(CodDiario, SeccDiario);
            'BRD':
                FormatoRES(CodDiario, SeccDiario);
        end;
    end;
    //[Scope('Cloud')]



    local procedure FormatoBPD(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        GenJnlLine2: Record "Gen. Journal Line";
        RNC: Text[30];
        Blanco: Text[60];
        Cero: Text[1];
        FechaTrans: Date;
        Mes: Integer;
        Secuencia: Code[10];
        CodBco: Code[20];
        Total: Decimal;
        Contador: Integer;

    begin
        CompanyInfo.GET();
        ConfContab.GET();
        CompanyInfo.TESTFIELD("VAT Registration No.");
        RNC := DELCHR(CompanyInfo."VAT Registration No.", '=', '-');

        Blanco := ' ';
        Cero := '0';
        CRLF[1] := 13;
        CRLF[2] := 10;
        PrimeraVez := TRUE;
        TotalGeneral := 0;
        BankAccount.TESTFIELD("DSNIdentificador Empresa");

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);

        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDFIRST;

        IF GenJnlLine."Posting Date" < TODAY THEN
            ERROR(Err003);

        FechaTrans := GenJnlLine."Posting Date";

        NombreArchivo := 'PE' + BankAccount."DSNIdentificador Empresa" + FORMAT(FechaTrans, 0, '<Month,2>') + FORMAT(FechaTrans, 0, '<Day,2>');

        Mes := DATE2DMY(FechaTrans, 2);
        Mes := Mes * 2;

        IF BankAccount.DSNSecuencia = '' THEN BEGIN
            IF Mes < 10 THEN
                BankAccount.DSNSecuencia := '000000' + FORMAT(Mes)
            ELSE
                BankAccount.DSNSecuencia := '00000' + FORMAT(Mes);

            BankAccount.DSNSecuencia := INCSTR(BankAccount.DSNSecuencia);
            BankAccount.MODIFY;
        END
        ELSE BEGIN
            BankAccount.DSNSecuencia := INCSTR(BankAccount.DSNSecuencia);
            BankAccount.MODIFY;
            Secuencia := BankAccount.DSNSecuencia;
        END;
        NombreArchivo += '01' + 'E.txt';

        SecuenciaTrans := '0000000';

        TmpBlob.CREATEOUTSTREAM(StreamOut);

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);

        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDSET;
        CounterTotal := GenJnlLine.COUNT;
        Window.OPEN(Text001);

        REPEAT
            Counter := Counter + 1;
            Window.UPDATE(1, GenJnlLine."Account No.");
            Window.UPDATE(2, ROUND(Counter / CounterTotal * 10000, 1));
            IF PrimeraVez THEN BEGIN
                PrimeraVez := FALSE;
                //Creo la cabecera
                GenJnlLine2.RESET;
                GenJnlLine2.COPYFILTERS(GenJnlLine);

                GenJnlLine2.FINDSET;
                REPEAT
                    TotalGeneral += ROUND(GenJnlLine2.Amount, 0.01);
                UNTIL GenJnlLine2.NEXT = 0;

                Lin_Body := 'H';
                Lin_Body += FORMAT(RNC, 15);
                Lin_Body += FORMAT(CompanyInfo.Name, 35);
                Lin_Body += Format(Secuencia + '02', 7);
                Lin_Body += '03';
                Lin_Body += FORMAT(FechaTrans, 8, '<Year4><Month,2><Day,2>');

                Lin_Body += FORMAT(CounterTotal, 11, '<Integer,11><Filler Character,0>');
                Lin_Body += FORMAT(TotalGeneral * 100, 13, '<integer,13><Filler Character,0>');
                Lin_Body += '000000000000000000000000';
                Lin_Body += '000000000000000';
                Lin_Body += FORMAT(TODAY, 8, '<Year4><Month,2><Day,2>');
                Lin_Body += FORMAT(TIME, 4, '<hours24,2><Minutes,2>');
                Lin_Body += FORMAT(CompanyInfo."E-Mail", 40);
                Lin_Body += FORMAT(Blanco, 136);
                StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));
            END;

            //Creo el detalle
            CLEAR(Customer);
            SecuenciaTrans := INCSTR(SecuenciaTrans);
            CLEAR(Lin_Body);
            Lin_Body := 'N';
            Lin_Body += FORMAT(RNC, 15);
            Lin_Body += FORMAT(Secuencia, 7);
            Lin_Body += FORMAT(SecuenciaTrans, 7);


            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Customer THEN BEGIN
                Customer.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                CustomerBank.RESET;
                CustomerBank.SETRANGE("Customer No.", GenJnlLine."Account No.");
                CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                CustomerBank.FINDFIRST;
                CustomerBank.TESTFIELD("Bank Account No.");
                CustomerBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(CustomerBank."DSNBanco RED ACH");

            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Customer THEN BEGIN
                    Customer.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    CustomerBank.RESET;
                    CustomerBank.SETRANGE("Customer No.", GenJnlLine."Bal. Account No.");
                    CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    CustomerBank.FINDFIRST;
                    CustomerBank.TESTFIELD("Bank Account No.");
                    CustomerBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(CustomerBank."DSNBanco RED ACH");

                END;

            BankAccount."Bank Account No." := DELCHR(BankAccount."Bank Account No.", '=', '-/., ');

            //DSNTipo Cuenta ==> 0= ahorro, 1= Corriente, 2 = cheque
            IF (GenJnlLine."Account Type" = GenJnlLine."Account Type"::"Bank Account") AND  // Para cuando es transferencias entre bancos
               (GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::"Bank Account") THEN BEGIN
                BankAccount2.GET(GenJnlLine."Account No.");
                BankAccount2.TESTFIELD("Bank Account No.");
                //BankAccount2.TESTFIELD("Bank Code");
                BankAccount2."Bank Account No." := DELCHR(BankAccount2."Bank Account No.", '=', '-/., ');

                Lin_Body += FORMAT(BankAccount2."Bank Account No.") + FORMAT(Blanco, 20 - STRLEN(BankAccount2."Bank Account No."));
                Lin_Body += '1';
                IF STRPOS(ConfContab."LCY Code", 'US') <> 0 THEN BEGIN
                    IF STRPOS(GenJnlLine."Currency Code", 'DO') <> 0 THEN
                        Lin_Body += '214'
                    ELSE
                        IF STRPOS(GenJnlLine."Currency Code", 'EU') <> 0 THEN
                            Lin_Body += '978'
                        ELSE
                            Lin_Body += '840'; //Moneda 214=RD$, 840=USD, 978=Euro
                END
                ELSE
                    IF STRPOS(ConfContab."LCY Code", 'DO') <> 0 THEN BEGIN
                        IF STRPOS(GenJnlLine."Currency Code", 'US') <> 0 THEN
                            Lin_Body += '840'
                        ELSE
                            IF STRPOS(GenJnlLine."Currency Code", 'EU') <> 0 THEN
                                Lin_Body += '978'
                            ELSE
                                Lin_Body += '214'; //Moneda 214=RD$, 840=USD, 978=Euro
                    END;

                Lin_Body += BankAccount2."SWIFT Code";//Aqui debe tener el Identificador del banco + codigo ACH + Digito de chequeo
                Customer."E-Mail" := BankAccount2."E-Mail";

                IF BankAccount2."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CC= Cuenta Corriente" THEN //Corriente
                    Lin_Body += '27'
                ELSE
                    IF BankAccount2."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" THEN //Ahorro
                        Lin_Body += '32'
                    ELSE
                        Lin_Body += '52'; //Tarjeta o Prestamo
            END
            ELSE BEGIN
                IF (CustomerBank."Bank Account No." <> '') AND (CustomerBank."DSNTipo Cuenta" <> BankAccount2."DSNTipo Cuenta"::"TJ= Tarjeta") THEN
                    Lin_Body += FORMAT(CustomerBank."Bank Account No.") + FORMAT(Blanco, 20 - STRLEN(CustomerBank."Bank Account No."))
                ELSE
                    IF CustomerBank."DSNTipo Cuenta" <> BankAccount2."DSNTipo Cuenta"::"TJ= Tarjeta" THEN
                        ERROR(Err002, GenJnlLine."Account No." + ', ' + GenJnlLine.DSNBeneficiario)
                    ELSE
                        IF CustomerBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"TJ= Tarjeta" THEN
                            Lin_Body += FORMAT(Blanco, 20);

                IF CustomerBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CC= Cuenta Corriente" THEN //Corriente
                    Lin_Body += '1'
                ELSE
                    IF CustomerBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" THEN //Ahorro
                        Lin_Body += '2'
                    ELSE
                        Lin_Body += '5';

                IF STRPOS(ConfContab."LCY Code", 'US') <> 0 THEN BEGIN
                    IF STRPOS(GenJnlLine."Currency Code", 'DO') <> 0 THEN
                        Lin_Body += '214'
                    ELSE
                        IF STRPOS(GenJnlLine."Currency Code", 'EU') <> 0 THEN
                            Lin_Body += '978'
                        ELSE
                            Lin_Body += '840'; //Moneda 214=RD$, 840=USD, 978=Euro

                    BcoACH.GET(CustomerBank."DSNBanco RED ACH");
                    IF (STRPOS(GenJnlLine."Currency Code", 'DO') = 0) AND (BcoACH."Codigo Banco" <> 'BPD') THEN BEGIN
                        Lin_Body += '8' + COPYSTR(BcoACH."Codigo ACH", 2, 10);
                        Lin_Body += 'L';
                    END
                    ELSE BEGIN
                        Lin_Body += BcoACH."Codigo ACH";
                        Lin_Body += FORMAT(BcoACH."Digito Chequeo");
                    END;
                END
                ELSE
                    IF STRPOS(ConfContab."LCY Code", 'DO') <> 0 THEN BEGIN
                        IF STRPOS(GenJnlLine."Currency Code", 'US') <> 0 THEN
                            Lin_Body += '840'
                        ELSE
                            IF STRPOS(GenJnlLine."Currency Code", 'EU') <> 0 THEN
                                Lin_Body += '978'
                            ELSE
                                Lin_Body += '214'; //Moneda 214=RD$, 840=USD, 978=Euro

                        BcoACH.GET(CustomerBank."DSNBanco RED ACH");
                        IF (GenJnlLine."Currency Code" = '') OR (BcoACH."Codigo Banco" = 'BPD') THEN BEGIN
                            Lin_Body += BcoACH."Codigo ACH";
                            Lin_Body += FORMAT(BcoACH."Digito Chequeo");
                        END
                        ELSE BEGIN
                            Lin_Body += '8' + COPYSTR(BcoACH."Codigo ACH", 2, 10);
                            Lin_Body += 'L';
                        END;
                    END;

                IF CustomerBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CC= Cuenta Corriente" THEN //Corriente
                    Lin_Body += '27'
                ELSE
                    IF CustomerBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" THEN //Ahorro
                        Lin_Body += '32'
                    ELSE
                        Lin_Body += '12';
            END;

            Lin_Body += FORMAT(GenJnlLine.Amount * 100, 13, '<integer,13><Filler Character,0>');

            // Se cambia por tipo doc y numero Lin_Body += FORMAT(Blanco,17,'<Text,17>');
            Customer."VAT Registration No." := DELCHR(Customer."VAT Registration No.", '=', '-');
            IF STRLEN(Customer."VAT Registration No.") > 9 THEN
                Lin_Body += 'CE'
            ELSE
                Lin_Body += 'RN';

            Lin_Body += Format(GenJnlLine."VAT Registration No.", 15); //RNC

            Lin_Body += FORMAT(Customer.Name, 35); //nombre beneficiario
            if GenJnlLine."Applies-to Doc. No." <> '' then
                Lin_Body += format(GenJnlLine."Applies-to Doc. No.") + PADSTR(Blanco, 12 - STRLEN(format(GenJnlLine."Applies-to Doc. No."))) //numero de referencia
            else
                buscarAplicacion();
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            IF STRPOS(GenJnlLine.Description, ',') <> 0 THEN
                Lin_Body += FORMAT(COPYSTR(COPYSTR(GenJnlLine.Description, 1, STRPOS(GenJnlLine.Description, ',') - 1) + '-' + GenJnlLine.Description, 1, 40), 40)
            ELSE
                Lin_Body += FORMAT(COPYSTR(GenJnlLine.Description, 1, 40), 40);
            Lin_Body += FORMAT(Blanco, 4);
            IF Customer."E-Mail" <> '' THEN
                Lin_Body += '1'
            ELSE
                Lin_Body += ' ';

            IF STRLEN(Customer."E-Mail") <= 40 THEN
                Lin_Body += FORMAT(Customer."E-Mail", 40);

            Lin_Body += FORMAT(Blanco, 12);
            Lin_Body += '00';

            Lin_Body += FORMAT(Blanco, 78);
            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));

            Contador := Contador + 1;

            Tracenumber := FORMAT(CURRENTDATETIME);
            Tracenumber := DELCHR(Tracenumber, '=', '._-:');
            ExportAmount := GenJnlLine.Amount;


            GenJnlLine."Exported to Payment File" := TRUE;

            GenJnlLine.MODIFY;

        UNTIL GenJnlLine.NEXT = 0;
        Window.CLOSE;

        TmpBlob.CREATEINSTREAM(StreamIn);

        if CompanyInfo."DSNGuardar arch. elect. en" = 0 then //PC
            DOWNLOADFROMSTREAM(StreamIn, 'BPD', 'c:\Nominas\Bancos\BPD', '', NombreArchivo)
        else
            DocumentServiceManagement.ShareWithOneDrive(NombreArchivo, '.txt', StreamIn)
    end;

    local procedure FormatoBHD(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        GenJnlLine2: Record "Gen. Journal Line";
        Secuencia: Text;
        CodBco: Code[20];
        RNC: Code[20];
    begin
        //BHD
        CompanyInfo.GET();
        CompanyInfo.TESTFIELD("VAT Registration No.");
        RNC := DELCHR(CompanyInfo."VAT Registration No.", '=', '-');
        Blanco := ' ';
        CERO := '0';
        TotalGeneral := 0;
        PrimeraVez := TRUE;
        BankAccount.TESTFIELD("DSNIdentificador Empresa");

        //Leemos el diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);

        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDFIRST;
        NombreArchivo := 'PE-BHD-' + BankAccount."DSNIdentificador Empresa" + '-' + FORMAT(WORKDATE, 0, '<Month,2>') + FORMAT(WORKDATE, 0, '<Day,2>');
        IF BankAccount.DSNSecuencia = '' THEN BEGIN
            Secuencia := 'HHH0000000';
            BankAccount.DSNSecuencia := INCSTR(BankAccount.DSNSecuencia);
            BankAccount.MODIFY;
        END;
        SecuenciaTrans := BankAccount.DSNSecuencia;
        NombreArchivo += Secuencia + '.txt';

        TmpBlob.CREATEOUTSTREAM(StreamOut);
        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);

        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDSET;
        CounterTotal := GenJnlLine.COUNT;
        Window.OPEN(Text001);
        REPEAT
            Counter := Counter + 1;
            Window.UPDATE(1, GenJnlLine."Account No.");
            Window.UPDATE(2, ROUND(Counter / CounterTotal * 10000, 1));
            IF GenJnlLine."Posting Date" < WORKDATE THEN
                ERROR(Err003);
            //Creo el detalle
            CLEAR(Customer);
            CLEAR(Lin_Body);
            IF PrimeraVez THEN BEGIN
                PrimeraVez := FALSE;
                SecuenciaTrans := 'HHH0000000';
                //Creo la cabecera
                BankAccount."Bank Account No." := DELCHR(BankAccount."Bank Account No.", '=', '-/., ');
                Lin_Body := BankAccount."Bank Account No." + ';'; //Cuenta de la empresa       GenJnlLine2.RESET;
                GenJnlLine2.COPYFILTERS(GenJnlLine);

                GenJnlLine2.FINDSET;
                REPEAT
                    TotalGeneral += ROUND(GenJnlLine2.Amount, 0.01);
                UNTIL GenJnlLine2.NEXT = 0;
                Lin_Body := BankAccount."Bank Account No." + ';';
                Lin_Body += 'BHD;';
                Lin_Body += 'CC;';
                Lin_Body += DELCHR(CompanyInfo.Name, '=', ';') + ';';
                Lin_Body += 'D;';
                Lin_Body += FORMAT(TotalGeneral, 0, '<Integer><Decimals,3>') + ';';
                Lin_Body += SecuenciaTrans + ';';
                Lin_Body += 'TRANSFERENCIA ELECTRONICA;';
                StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));
            END;

            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Customer THEN BEGIN
                Customer.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                CustomerBank.RESET;
                CustomerBank.SETRANGE("Customer No.", GenJnlLine."Account No.");
                CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                CustomerBank.FINDFIRST;
                CustomerBank.TESTFIELD("Bank Account No.");
                CustomerBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(CustomerBank."DSNBanco RED ACH");

            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Customer THEN BEGIN
                    Customer.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    CustomerBank.RESET;
                    CustomerBank.SETRANGE("Customer No.", GenJnlLine."Bal. Account No.");
                    CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    CustomerBank.FINDFIRST;
                    CustomerBank.TESTFIELD("Bank Account No.");
                    CustomerBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(CustomerBank."DSNBanco RED ACH");

                END;
            BcoACH.GET(CustomerBank."DSNBanco RED ACH");
            CLEAR(Lin_Body);
            CustomerBank."Bank Account No." := DELCHR(CustomerBank."Bank Account No.", '=', '-/., ');
            Lin_Body := CustomerBank."Bank Account No." + ';'; //Cuenta del proveedor
            Lin_Body += BcoACH."Codigo Banco" + ';'; //Banco y ruta destino
            IF CustomerBank."DSNTipo Cuenta" = 0 THEN //Corriente
                Lin_Body += 'CC'
            ELSE
                IF CustomerBank."DSNTipo Cuenta" = 1 THEN //Ahorro
                    Lin_Body += 'CA'
                ELSE
                    Lin_Body += 'PR';
            GenJnlLine.DSNBeneficiario := DELCHR(GenJnlLine.DSNBeneficiario, '=', ';');
            Lin_Body += ';' + COPYSTR(GenJnlLine.DSNBeneficiario, 1, 22) + ';';
            Lin_Body += 'C;';
            Lin_Body += FORMAT(GenJnlLine.Amount, 0, '<Integer><Decimals,3>') + ';';
            SecuenciaTrans := INCSTR(SecuenciaTrans);
            Lin_Body += SecuenciaTrans + ';';
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DELCHR(GenJnlLine.Description, '=', ';');
            Lin_Body += COPYSTR(GenJnlLine.Description, 1, 80) + ';';
            Lin_Body += Customer."E-Mail";
            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));
            Tracenumber := FORMAT(CURRENTDATETIME);
            Tracenumber := DELCHR(Tracenumber, '=', '._-:');
            ExportAmount := GenJnlLine.Amount;
            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;


            //eliminar hhh a la secuencia para campo "EP Bulk No. Line"
            BankAccount.MODIFY;
            GenJnlLine."Exported to Payment File" := TRUE;

            GenJnlLine.MODIFY;
        UNTIL GenJnlLine.NEXT = 0;
        BankAccount.DSNSecuencia := SecuenciaTrans;
        BankAccount.MODIFY;
        Window.CLOSE;
        TmpBlob.CREATEINSTREAM(StreamIn);
        if CompanyInfo."DSNGuardar arch. elect. en" = 0 then //PC
            DOWNLOADFROMSTREAM(StreamIn, 'BHD', 'c:\Nominas\Bancos\BHD', '', NombreArchivo)
        else
            DocumentServiceManagement.ShareWithOneDrive(NombreArchivo, '.txt', StreamIn)
    end;

    local procedure FormatoBHDLBTR(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        GenJnlLine2: Record "Gen. Journal Line";
        Secuencia: Text;
        CodBco: Code[20];
        RNC: Code[20];

    begin
        CompanyInfo.GET();
        CompanyInfo.TESTFIELD("VAT Registration No.");
        RNC := DELCHR(CompanyInfo."VAT Registration No.", '=', '-');

        Blanco := ' ';
        CERO := '0';
        TotalGeneral := 0;
        PrimeraVez := TRUE;
        BankAccount.TESTFIELD("DSNIdentificador Empresa");

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SETRANGE("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDFIRST;
        NombreArchivo := 'PE-BHD-' + BankAccount."DSNIdentificador Empresa" + '-' + FORMAT(WORKDATE, 0, '<Month,2>') + FORMAT(WORKDATE, 0, '<Day,2>');
        IF BankAccount.DSNSecuencia = '' THEN BEGIN
            Secuencia := 'HHH0000000';

            BankAccount.DSNSecuencia := INCSTR(BankAccount.DSNSecuencia);
            BankAccount.MODIFY;
        END;

        SecuenciaTrans := BankAccount.DSNSecuencia;
        NombreArchivo += Secuencia + '.txt';


        TmpBlob.CREATEOUTSTREAM(StreamOut);

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SETRANGE("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDSET;
        CounterTotal := GenJnlLine.COUNT;
        Window.OPEN(Text001);
        REPEAT
            Counter := Counter + 1;
            Window.UPDATE(1, GenJnlLine."Account No.");
            Window.UPDATE(2, ROUND(Counter / CounterTotal * 10000, 1));

            IF GenJnlLine."Posting Date" < WORKDATE THEN
                ERROR(Err003);

            //Creo el detalle
            CLEAR(Customer);
            CLEAR(Lin_Body);

            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Customer THEN BEGIN
                Customer.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                CustomerBank.RESET;
                CustomerBank.SETRANGE("Customer No.", GenJnlLine."Account No.");
                CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                CustomerBank.FINDFIRST;
                CustomerBank.TESTFIELD("Bank Account No.");
                CustomerBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(CustomerBank."DSNBanco RED ACH");

            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Customer THEN BEGIN
                    Customer.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    CustomerBank.RESET;
                    CustomerBank.SETRANGE("Customer No.", GenJnlLine."Bal. Account No.");
                    CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    CustomerBank.FINDFIRST;
                    CustomerBank.TESTFIELD("Bank Account No.");
                    CustomerBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(CustomerBank."DSNBanco RED ACH");

                END;
            BcoACH.GET(CustomerBank."DSNBanco RED ACH");

            CLEAR(Lin_Body);
            CustomerBank."Bank Account No." := DELCHR(CustomerBank."Bank Account No.", '=', '-/., ');
            Lin_Body := CustomerBank."Bank Account No." + ';'; //Cuenta del proveedor

            Lin_Body += BcoACH.Swift + ';'; //SWIFT
            IF CustomerBank."DSNTipo Cuenta" = 0 THEN //Corriente
                Lin_Body += 'CC'
            ELSE
                IF CustomerBank."DSNTipo Cuenta" = 1 THEN //Ahorro
                    Lin_Body += 'CA'
                ELSE
                    Lin_Body += 'PR';

            Lin_Body += 'C;';

            GenJnlLine.DSNBeneficiario := DELCHR(GenJnlLine.DSNBeneficiario, '=', ';');
            Lin_Body += ';' + COPYSTR(GenJnlLine.DSNBeneficiario, 1, 22) + ';';

            Lin_Body += FORMAT(GenJnlLine.Amount, 0, '<Integer><Decimals,3>') + ';';
            SecuenciaTrans := INCSTR(SecuenciaTrans);
            Lin_Body += SecuenciaTrans + ';';
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DELCHR(GenJnlLine.Description, '=', ';');
            Lin_Body += COPYSTR(GenJnlLine.Description, 1, 80) + ';';
            Lin_Body += Customer."E-Mail" + ';';
            Customer."VAT Registration No." := DELCHR(Customer."VAT Registration No.", '=', '-');
            Lin_Body += Customer."VAT Registration No.";


            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));


            ExportAmount := GenJnlLine.Amount;
            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;


            // eliminar hhh a la secuencia para campo "EP Bulk No. Line"

            BankAccount.MODIFY;
            GenJnlLine."Exported to Payment File" := TRUE;
            GenJnlLine.MODIFY;
        UNTIL GenJnlLine.NEXT = 0;

        BankAccount.DSNSecuencia := SecuenciaTrans;
        BankAccount.MODIFY;

        Window.CLOSE;
        TmpBlob.CREATEINSTREAM(StreamIn);
        if CompanyInfo."DSNGuardar arch. elect. en" = 0 then //PC
            DOWNLOADFROMSTREAM(StreamIn, 'BHD', 'c:\Nominas\Bancos\BHD', '', NombreArchivo)
        else
            DocumentServiceManagement.ShareWithOneDrive(NombreArchivo, '.txt', StreamIn)
    end;

    local procedure FormatoBHDMP(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        Secuencia: Text;
        CodBco: Code[20];
        RNC: Code[20];
    begin
        CompanyInfo.GET();
        CompanyInfo.TESTFIELD("VAT Registration No.");
        RNC := DELCHR(CompanyInfo."VAT Registration No.", '=', '-');

        Blanco := ' ';
        CERO := '0';
        TotalGeneral := 0;
        PrimeraVez := TRUE;
        CRLF[1] := 13;
        CRLF[2] := 10;

        BankAccount.TESTFIELD("DSNIdentificador Empresa");

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SETRANGE("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDFIRST;

        IF BankAccount.DSNSecuencia = '' THEN
            BankAccount.DSNSecuencia := '0000';

        BankAccount.DSNSecuencia := INCSTR(BankAccount.DSNSecuencia);
        BankAccount.MODIFY;

        NombreArchivo := BankAccount."DSNIdentificador Empresa" + '-' + FORMAT(TODAY, 0, '<Day,2><Month,2><Year4>') + '-' + BankAccount.DSNSecuencia;
        SecuenciaTrans := BankAccount.DSNSecuencia;
        NombreArchivo += '.txt';


        TmpBlob.CREATEOUTSTREAM(StreamOut);

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);

        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SETRANGE("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDSET;
        CounterTotal := GenJnlLine.COUNT;
        Window.OPEN(Text001);
        REPEAT
            Counter := Counter + 1;
            Window.UPDATE(1, GenJnlLine."Account No.");
            Window.UPDATE(2, ROUND(Counter / CounterTotal * 10000, 1));

            IF GenJnlLine."Posting Date" < WORKDATE THEN
                ERROR(Err003);

            //Creo la cabecera
            IF PrimeraVez THEN BEGIN
                BankAccount."Bank Account No." := DELCHR(BankAccount."Bank Account No.", '=', '-/., ');
                CLEAR(Lin_Body);
                Lin_Body := BankAccount."Bank Account No." + ';'; //Cuenta de la empresa

                Lin_Body := BankAccount."Bank Account No." + ';';
                IF GenJnlLine."Currency Code" <> '' THEN BEGIN
                    IF STRPOS(GenJnlLine."Currency Code", 'US') <> 0 THEN
                        Lin_Body += 'US;'
                    ELSE
                        IF STRPOS(GenJnlLine."Currency Code", 'EU') <> 0 THEN
                            Lin_Body += 'EU;'
                        ELSE
                            ERROR(STRSUBSTNO(GenJnlLine.FIELDCAPTION("Currency Code"), GenJnlLine."Currency Code"));
                END
                ELSE
                    Lin_Body += 'RD;';

                Lin_Body += FORMAT(GenJnlLine."Posting Date", 0, '<Day,2><Month,2><Year4>') + ';';
                Lin_Body += 'I;'; // I=Individual, T=Total
                StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));

                PrimeraVez := FALSE;
                SecuenciaTrans := '000000';
            END;

            //Creo el detalle
            CLEAR(Customer);
            CLEAR(Lin_Body);

            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Customer THEN BEGIN
                Customer.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                CustomerBank.RESET;
                CustomerBank.SETRANGE("Customer No.", GenJnlLine."Account No.");
                CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                CustomerBank.FINDFIRST;
                CustomerBank.TESTFIELD("Bank Account No.");
                CustomerBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(CustomerBank."DSNBanco RED ACH");
                BcoACH.TESTFIELD("Codigo Banco");
            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Customer THEN BEGIN
                    Customer.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    CustomerBank.RESET;
                    CustomerBank.SETRANGE("Customer No.", GenJnlLine."Bal. Account No.");
                    CustomerBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    CustomerBank.FINDFIRST;
                    CustomerBank.TESTFIELD("Bank Account No.");
                    CustomerBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(CustomerBank."DSNBanco RED ACH");
                    BcoACH.TESTFIELD("Codigo Banco");
                END;

            CLEAR(Lin_Body);
            IF BcoACH."Codigo Banco" <> 'BHD' THEN //Para tipo de trasaccion
                Lin_Body := '4;'
            ELSE
                Lin_Body := '1;';

            Lin_Body += BcoACH."Codigo Banco" + ';'; //Codigo del banco destino

            CustomerBank."Bank Account No." := DELCHR(CustomerBank."Bank Account No.", '=', '-/., ');
            IF CustomerBank."DSNTipo Cuenta" = 0 THEN //Corriente
                Lin_Body += 'CC;'
            ELSE
                IF CustomerBank."DSNTipo Cuenta" = 1 THEN //Ahorro
                    Lin_Body += 'CA;'
                ELSE
                    IF CustomerBank."DSNTipo Cuenta" = 2 THEN //Tarjeta
                        Lin_Body += 'TJ;'
                    ELSE
                        Lin_Body += 'PR;'; //Prestamo

            Lin_Body += CustomerBank."Bank Account No." + ';'; //Cuenta del proveedor
            Lin_Body += FORMAT(GenJnlLine.Amount, 0, '<Integer><Decimals,3>') + ';'; //Monto transaccion


            IF STRLEN(Customer."VAT Registration No.") < 11 THEN //Tipo de documento
                Lin_Body += 'R;'
            ELSE
                IF STRLEN(Customer."VAT Registration No.") = 11 THEN
                    Lin_Body += 'C;'
                ELSE
                    Lin_Body += 'P;';

            Lin_Body += DELCHR(Customer."VAT Registration No.", '=', ' -;') + ';'; //Numero de documento


            GenJnlLine.DSNBeneficiario := DELCHR(GenJnlLine.DSNBeneficiario, '=', ';');
            Lin_Body += COPYSTR(GenJnlLine.DSNBeneficiario, 1, 22) + ';';
            Lin_Body += ';'; //Pais de nacimiento. Solo para pagos BCRD con tipo documento P
            Lin_Body += ';'; //Sexo. Solo para pagos BCRD con tipo documento P
            Lin_Body += ';'; //Tipo de registro. I= Inclusión (Cuando se desea inscribir un pago). C= - Cancelación (Cuando se desea cancelar un pago previamente inscrito y no combrado)


            Lin_Body += FORMAT(GenJnlLine."Line No.") + ';'; //Referencia
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DELCHR(GenJnlLine.Description, '=', ';');
            Lin_Body += COPYSTR(GenJnlLine.Description, 1, 80) + ';'; //Descripcion
            Lin_Body += CustomerBank."E-Mail" + ';'; //Correo electronico beneficiario
            Lin_Body += ';'; //Campo Opcional 2

            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));

            Tracenumber := FORMAT(CURRENTDATETIME);
            Tracenumber := DELCHR(Tracenumber, '=', '._-:');
            ExportAmount := GenJnlLine.Amount;
            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;


            // eliminar hhh a la secuencia para campo "EP Bulk No. Line"
            BankAccount.MODIFY;


            GenJnlLine."Exported to Payment File" := TRUE;

        UNTIL GenJnlLine.NEXT = 0;

        BankAccount.DSNSecuencia := SecuenciaTrans;
        BankAccount.MODIFY;

        Window.CLOSE;

        TmpBlob.CREATEINSTREAM(StreamIn);

        if CompanyInfo."DSNGuardar arch. elect. en" = 0 then //PC
            DOWNLOADFROMSTREAM(StreamIn, 'BHD', 'c:\Nominas\Bancos\BHD', '', NombreArchivo)
        else
            DocumentServiceManagement.ShareWithOneDrive(NombreArchivo, '.txt', StreamIn)
    end;

    local procedure FormatoRES(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        Secuencia: Text;
        CodBco: Code[20];
        RNC: Code[20];
    begin
        //Reservas

        CompanyInfo.Get();
        CompanyInfo.TestField("VAT Registration No.");
        RNC := DelChr(CompanyInfo."VAT Registration No.", '=', '-');

        Blanco := ' ';
        CERO := '0';
        TotalGeneral := 0;
        BankAccount.TestField("DSNIdentificador Empresa");

        //Leemos el Diario
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);

        GenJnlLine.SetRange("Document Type", GenJnlLine."Document Type"::Payment);

        GenJnlLine.SetFilter(Amount, '<>%1', 0);
        GenJnlLine.FindFirst;

        IF GenJnlLine."Posting Date" < TODAY THEN
            ERROR(Err003);
        FechaTrans := GenJnlLine."Posting Date";

        NombreArchivo := 'PE-BR-' + BankAccount."DSNIdentificador Empresa" + '-' + Format(WorkDate, 0, '<Month,2>') + Format(WorkDate, 0, '<Day,2>');

        if BankAccount.DSNSecuencia = '' then begin
            Secuencia := '000000';

            BankAccount.DSNSecuencia := IncStr(BankAccount.DSNSecuencia);
            BankAccount.Modify;
        end
        else begin
            BankAccount.DSNSecuencia := IncStr(BankAccount.DSNSecuencia);
            BankAccount.Modify;
            Secuencia := BankAccount.DSNSecuencia;
        end;
        NombreArchivo += Secuencia + '.txt';
        TmpBlob.CREATEOUTSTREAM(StreamOut);

        //Leemos el Diario
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);

        GenJnlLine.SetRange("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SetRange("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SetFilter(Amount, '<>%1', 0);
        GenJnlLine.FindSet;
        CounterTotal := GenJnlLine.Count;
        Window.Open(Text001);
        repeat
            Counter := Counter + 1;
            Window.Update(1, GenJnlLine."Account No.");
            Window.Update(2, Round(Counter / CounterTotal * 10000, 1));

            if GenJnlLine."Posting Date" < Today then
                Error(Err003);

            //Creo el detalle
            Clear(Customer);
            Clear(Lin_Body);
            if BankAccount."DSNTipo Cuenta" = BankAccount."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" then
                Lin_Body := 'ÇA'
            else
                Lin_Body := 'ÇC';

            if BankAccount."Currency Code" = '' then
                Lin_Body += 'DOP'
            else
                Lin_Body += BankAccount."Currency Code";
            BankAccount."Bank Account No." := DelChr(BankAccount."Bank Account No.", '=', '-/., ');
            Lin_Body += BankAccount."Bank Account No." + ','; //Cuenta de origen

            if GenJnlLine."Account Type" = GenJnlLine."Account Type"::Customer then begin
                Customer.Get(GenJnlLine."Account No.");
                BankAccount.Get(GenJnlLine."Bal. Account No.");
                CustomerBank.Reset;
                CustomerBank.SetRange("Customer No.", GenJnlLine."Account No.");
                CustomerBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                CustomerBank.FindFirst;
                CustomerBank.TestField("Bank Account No.");
                CustomerBank.TestField("DSNBanco RED ACH");
                BcoACH.Get(CustomerBank."DSNBanco RED ACH");

            end
            else
                if GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Customer then begin
                    Customer.Get(GenJnlLine."Bal. Account No.");
                    BankAccount.Get(GenJnlLine."Account No.");
                    CustomerBank.Reset;
                    CustomerBank.SetRange("Customer No.", GenJnlLine."Bal. Account No.");
                    CustomerBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    CustomerBank.FindFirst;
                    CustomerBank.TestField("Bank Account No.");
                    CustomerBank.TestField("DSNBanco RED ACH");
                    BcoACH.Get(CustomerBank."DSNBanco RED ACH");

                end;

            Lin_Body += BcoACH."Codigo ACH" + ','; //Banco y ruta destino

            //DSNTipo Cuenta ==> AH= ahorro, CC= Corriente, TC = Tarjeta de crédito, PR = Préstamos
            if (CustomerBank."Bank Account No." <> '') and (CustomerBank."DSNTipo Cuenta" <> 2) then
                Lin_Body += CustomerBank."Bank Account No."
            else
                if CustomerBank."DSNTipo Cuenta" <> 2 then
                    Error(Err002, GenJnlLine."Account No." + ', ' + GenJnlLine.DSNBeneficiario)
                else
                    if CustomerBank."DSNTipo Cuenta" = 2 then
                        Lin_Body += Format(Blanco, 20);
            Lin_Body += ',';
            if CustomerBank."DSNTipo Cuenta" = 0 then //Corriente
                Lin_Body += 'CC'
            else
                Lin_Body += 'CA';

            CustomerBank."Bank Account No." := DelChr(CustomerBank."Bank Account No.", '=', '-/., ');

            Lin_Body += ',';
            Lin_Body += Format(GenJnlLine.Amount * 100, 13, '<integer,13><Filler Character,0>') + ',';
            GenJnlLine.DSNBeneficiario := DelChr(GenJnlLine.DSNBeneficiario, '=', ',');
            Lin_Body += CopyStr(GenJnlLine.DSNBeneficiario, 1, 22) + ',';
            Customer.TestField("VAT Registration No.");
            if StrLen(DelChr(Customer."VAT Registration No.", '=', ' -')) = 9 then
                Lin_Body += 'RNC'
            else
                if StrLen(DelChr(Customer."VAT Registration No.", '=', ' -')) = 11 then
                    Lin_Body += 'Cedula'
                else
                    Lin_Body += 'Pasaporte';
            Lin_Body += RNC + ',';
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DelChr(GenJnlLine.Description, '=', ',');
            Lin_Body += Format(CopyStr(GenJnlLine.Description, 1, 55), 55);
            StreamOut.WriteText(Lin_Body);
        until GenJnlLine.Next = 0;

        BankAccount.DSNSecuencia := SecuenciaTrans;
        BankAccount.MODIFY;
        Window.CLOSE;
        TmpBlob.CREATEINSTREAM(StreamIn);
        if CompanyInfo."DSNGuardar arch. elect. en" = 0 then //PC
            DOWNLOADFROMSTREAM(StreamIn, 'RES', 'c:\Nominas\Bancos\RES', '', NombreArchivo)
        else
            DocumentServiceManagement.ShareWithOneDrive(NombreArchivo, '.txt', StreamIn)

    end;

    local procedure FormatoSCA(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        Secuencia: Text[10];
        CodBco: Code[20];
        Contador: Integer;
    begin
        CompanyInfo.Get();

        Blanco := ' ';
        CERO := '0';
        TotalGeneral := 0;

        //Leemos el Diario
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);

        GenJnlLine.SetRange("Document Type", GenJnlLine."Document Type"::Payment);

        GenJnlLine.SetFilter(Amount, '<>%1', 0);
        GenJnlLine.FindFirst;

        BankAccount.Modify;
        NombreArchivo2 := NombreArchivo;

        //Leemos el Diario
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);

        GenJnlLine.SetRange("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SetRange("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SetFilter(Amount, '<>%1', 0);
        GenJnlLine.FindSet;
        CounterTotal := GenJnlLine.Count;
        Window.Open(Text001);

        repeat
            Counter := Counter + 1;
            Window.Update(1, GenJnlLine."Account No.");
            Window.Update(2, Round(Counter / CounterTotal * 10000, 1));

            if GenJnlLine."Posting Date" < Today then
                Error(Err003);

            //Creo el detalle
            Clear(Customer);
            Clear(Lin_Body);
            Contador := Contador + 1;

            if GenJnlLine."Account Type" = GenJnlLine."Account Type"::Customer then begin
                Customer.Get(GenJnlLine."Account No.");
                BankAccount.Get(GenJnlLine."Bal. Account No.");
                CustomerBank.Reset;
                CustomerBank.SetRange("Customer No.", GenJnlLine."Account No.");
                CustomerBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                CustomerBank.FindFirst;
                CustomerBank.TestField("Bank Account No.");
                CustomerBank.TestField("DSNBanco RED ACH");
                BcoACH.Get(CustomerBank."DSNBanco RED ACH");

            end
            else
                if GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Customer then begin
                    Customer.Get(GenJnlLine."Bal. Account No.");
                    BankAccount.Get(GenJnlLine."Account No.");
                    CustomerBank.Reset;
                    CustomerBank.SetRange("Customer No.", GenJnlLine."Bal. Account No.");
                    CustomerBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    CustomerBank.FindFirst;
                    CustomerBank.TestField("Bank Account No.");
                    CustomerBank.TestField("DSNBanco RED ACH");
                    BcoACH.Get(CustomerBank."DSNBanco RED ACH");

                end;

            BankAccount."Bank Account No." := DelChr(BankAccount."Bank Account No.", '=', '-/., ');
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DelChr(GenJnlLine.Description, '=', ',');
            GenJnlLine.DSNBeneficiario := DelChr(GenJnlLine.DSNBeneficiario, '=', ',');

            //DSNTipo Cuenta ==> 0= ahorro, 1= Corriente, 2 = cheque
            if (GenJnlLine."Account Type" = GenJnlLine."Account Type"::"Bank Account") and  // Para cuando es transferencias entre bancos
               (GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::"Bank Account") then begin
                BankAccount2.Get(GenJnlLine."Account No.");
                BankAccount2.TestField("Bank Account No.");

                BankAccount2."Bank Account No." := DelChr(BankAccount2."Bank Account No.", '=', '-/., ');
                Clear(Lin_Body);
                Lin_Body := Format(CopyStr(GenJnlLine.DSNBeneficiario, 1, 32), 32);
                Lin_Body += ',';
                if GenJnlLine."Account Type" = GenJnlLine."Account Type"::Customer then
                    Lin_Body += Format(DelChr(Customer."VAT Registration No.", '=', ' .-'))
                else
                    if GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Customer then
                        Lin_Body += Format(DelChr(Customer."VAT Registration No.", '=', ' .-'))
                    else
                        Lin_Body += Format(Counter, 0, '<Integer>');
                Lin_Body += ',';
                Lin_Body += CustomerBank."SWIFT Code";
                Lin_Body += ',';
                Lin_Body += BankAccount."Bank Account No.";
                Lin_Body += ',';
                if GenJnlLine."Currency Code" = '' then
                    Lin_Body += 'DOP'
                else
                    Lin_Body += GenJnlLine."Currency Code";

                Lin_Body += ',';
                if BankAccount."DSNTipo Cuenta" = BankAccount."DSNTipo Cuenta"::"CC= Cuenta Corriente" then
                    Lin_Body += 'Chequing'
                else
                    Lin_Body += 'Saving';
                Lin_Body += ',';
                Lin_Body += Format(GenJnlLine.Amount * 100, 10, '<Integer,10><Filler Character,0>');
                Lin_Body += ',';
                Lin_Body += CopyStr(GenJnlLine.Description, 1, 80);
                StreamOut.WriteText(Lin_Body);
            end
            else begin
                Clear(Lin_Body);
                Lin_Body := Format(CopyStr(GenJnlLine.DSNBeneficiario, 1, 32), 32);
                Lin_Body += ',';
                Counter += 1;
                Lin_Body += Format(Contador, 0, '<Integer>');
                Lin_Body += ',';
                Lin_Body += CustomerBank."SWIFT Code";
                Lin_Body += ',';
                Lin_Body += BankAccount."Bank Account No.";
                Lin_Body += ',';
                if GenJnlLine."Currency Code" = '' then
                    Lin_Body += 'DOP'
                else
                    Lin_Body += GenJnlLine."Currency Code";

                Lin_Body += ',';
                if BankAccount."DSNTipo Cuenta" = BankAccount."DSNTipo Cuenta"::"CC= Cuenta Corriente" then
                    Lin_Body += 'Chequing'
                else
                    Lin_Body += 'Saving';
                Lin_Body += ',';
                Lin_Body += Format(GenJnlLine.Amount * 100, 10, '<Integer,10><Filler Character,0>');
                Lin_Body += ',';
                Lin_Body += CopyStr(GenJnlLine.Description, 1, 80);
                StreamOut.WriteText(Lin_Body);
            end;

            ExportAmount := GenJnlLine.Amount;

            GenJnlLine."Check Printed" := true;
            GenJnlLine."Check Exported" := true;


            GenJnlLine."Exported to Payment File" := true;
            BankAccount.Modify;


            GenJnlLine.Modify;

        until GenJnlLine.Next = 0;
        BankAccount.DSNSecuencia := SecuenciaTrans;
        BankAccount.MODIFY;
        Window.CLOSE;
        TmpBlob.CREATEINSTREAM(StreamIn);
        if CompanyInfo."DSNGuardar arch. elect. en" = 0 then //PC
            DOWNLOADFROMSTREAM(StreamIn, 'SCA', 'c:\Nominas\Bancos\SCA', '', NombreArchivo)
        else
            DocumentServiceManagement.ShareWithOneDrive(NombreArchivo, '.txt', StreamIn)
    end;

    [Scope('Cloud')]
    procedure AnularTransmitido(var GeneralJournalLine: Record "Gen. Journal Line")
    begin
        GenJnlLine.CopyFilters(GeneralJournalLine);
        GenJnlLine.FindSet();
        repeat

            GenJnlLine."Check Transmitted" := false;

            GenJnlLine.Modify();
        until GenJnlLine.Next() = 0;
        Commit();
    end;

    local procedure buscarAplicacion()
    var
        CustomerLedgerEntry: record "Cust. Ledger Entry";
    begin
        CustomerLedgerEntry.Reset();
        CustomerLedgerEntry.SetCurrentKey("Customer No.", "Applies-to ID", Open, Positive, "Due Date");
        CustomerLedgerEntry.SetRange("Customer No.", GenJnlLine."Account No.");
        if GenJnlLine."Applies-to ID" <> '' then
            CustomerLedgerEntry.SetRange("Applies-to ID", GenJnlLine."Applies-to ID")
        else
            CustomerLedgerEntry.SetRange("Applies-to ID", GenJnlLine."Document No.");
        if not CustomerLedgerEntry.FindFirst() then
            CustomerLedgerEntry.Init();
        Lin_Body += format(CustomerLedgerEntry."Document No.") + PADSTR(Blanco, 12 - STRLEN(format(CustomerLedgerEntry."Document No."))) //numero de referencia
    end;

    [Scope('Cloud')]
    procedure Ascii2Ansi(_Text: Text[250]): Text[250]
    begin
        MakeVars();
        exit(ConvertStr(_Text, AsciiStr, AnsiStr));
    end;

    local procedure MakeVars()
    begin
        AsciiStr := 'áéíóúñÑAÉIOUü';
        AnsiStr := 'aeiounNAEIOUU';
    end;
}
