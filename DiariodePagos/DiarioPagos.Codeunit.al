codeunit 60100 "Genera Formatos  E. Nomina RD"
{
    Permissions = TableData Vendor = rimd,
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
        VendorBank: Record "Vendor Bank Account";
        Vendor: Record Vendor;

        DocumentServiceManagement: Codeunit "Document Service Management";
        StreamIn: InStream;
        StreamOut: OutStream;
        Lin_Body: Text[320];


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
    procedure FormatoBancoDiario(CodDiario: Code[20]; SeccDiario: Code[20])
    var
        Banco: Record "Bank Account";
        FirstTime: Boolean;
        BancoAnt: Code[20];
        Err001: Label 'The bank account must be the same in all the lines, please correct it';
    begin


    end;

    [Scope('Cloud')]
    procedure FormatoPagoProveedores(CodDiario: Code[20]; SeccDiario: Code[20]; PagoInstante: Integer)
    var
        Err001: Label 'The bank account must be the same in all the lines, please correct it';
        GenJnlLine: Record "Gen. Journal Line";
        VendorBank: Record "Vendor Bank Account";
        Vendor: Record Vendor;
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
        elimina();

        /*if (PagoInstante = 0) or (PagoInstante = 3) then
            exit;*/

        FirstTime := true;
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);
        GenJnlLine.SetRange("Check Printed", false);
        GenJnlLine.SetRange("Check Exported", false);
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
                begin

                    if PagoInstante = 2 then
                        "FormatoBHDLBTR"(CodDiario, SeccDiario) //Pagos al instante
                    else
                        if PagoInstante = 1 then
                            FormatoBHD(CodDiario, SeccDiario);

                end;
            'SCB':
                FormatoSCA(CodDiario, SeccDiario);
            'BRD':
                FormatoRES(CodDiario, SeccDiario);
        end;
    end;

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
        GenJnlLine.SETRANGE("Exported to Payment File", false);
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
        GenJnlLine.SETRANGE("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SETRANGE("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SETFILTER(Amount, '<>%1', 0);
        GenJnlLine.FINDFIRST;

        IF GenJnlLine."Posting Date" < TODAY THEN
            ERROR(Err003);

        FechaTrans := GenJnlLine."Posting Date";

        NombreArchivo := 'PE' + BankAccount."DSNIdentificador Empresa" + '01' + FORMAT(FechaTrans, 0, '<Month,2>') + FORMAT(FechaTrans, 0, '<Day,2>');

        Mes := DATE2DMY(FechaTrans, 2);
        Mes := Mes * 2;

        IF BankAccount.DSNSecuencia = '' THEN BEGIN
            IF Mes < 10 THEN
                Secuencia := '000000' + FORMAT(Mes)
            ELSE
                Secuencia := '00000' + FORMAT(Mes);

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
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
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
            IF PrimeraVez THEN BEGIN
                PrimeraVez := FALSE;
                //Creo la cabecera
                GenJnlLine2.RESET;
                GenJnlLine2.COPYFILTERS(GenJnlLine);
                GenJnlLine2.SETRANGE("Check Printed", FALSE);
                GenJnlLine2.SETRANGE("Check Exported", FALSE);
                GenJnlLine2.FINDSET;
                REPEAT
                    TotalGeneral += ROUND(GenJnlLine2.Amount, 0.01);
                UNTIL GenJnlLine2.NEXT = 0;

                Lin_Body := 'H';
                Lin_Body += FORMAT(RNC, 15);
                Lin_Body += FORMAT(CompanyInfo.Name, 35);
                Lin_Body += Secuencia + '02';
                Lin_Body += FORMAT(FechaTrans, 0, '<Year4><Month,2><Day,2>');
                Lin_Body += '000000000000000000000000';
                Lin_Body += FORMAT(CounterTotal, 11, '<Integer,11><Filler Character,0>');
                Lin_Body += FORMAT(TotalGeneral * 100, 13, '<integer,13><Filler Character,0>');
                Lin_Body += '000000000000000';
                Lin_Body += FORMAT(TODAY, 0, '<Year4><Month,2><Day,2>');
                Lin_Body += FORMAT(TIME, 4, '<hours24,2><Minutes,2>');
                Lin_Body += FORMAT(CompanyInfo."E-Mail", 40);
                Lin_Body += FORMAT(Blanco, 136);
                StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));
            END;

            //Creo el detalle
            CLEAR(Vendor);
            SecuenciaTrans := INCSTR(SecuenciaTrans);
            CLEAR(Lin_Body);
            Lin_Body := 'N';
            Lin_Body += FORMAT(RNC, 15);
            Lin_Body += FORMAT(Secuencia, 7);
            Lin_Body += FORMAT(SecuenciaTrans, 7);


            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Vendor THEN BEGIN
                Vendor.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                VendorBank.RESET;
                VendorBank.SETRANGE("Vendor No.", GenJnlLine."Account No.");
                VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                VendorBank.FINDFIRST;
                VendorBank.TESTFIELD("Bank Account No.");
                VendorBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(VendorBank."DSNBanco RED ACH");

            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Vendor THEN BEGIN
                    Vendor.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    VendorBank.RESET;
                    VendorBank.SETRANGE("Vendor No.", GenJnlLine."Bal. Account No.");
                    VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    VendorBank.FINDFIRST;
                    VendorBank.TESTFIELD("Bank Account No.");
                    VendorBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(VendorBank."DSNBanco RED ACH");
                    //BcoACH.TESTFIELD("Ruta y Transito");
                END;

            BankAccount."Bank Account No." := DELCHR(BankAccount."Bank Account No.", '=', '-/., ');

            //DSNTipo Cuenta ==> 0= ahorro, 1= Corriente, 2 = cheque
            IF (GenJnlLine."Account Type" = GenJnlLine."Account Type"::"Bank Account") AND  // Para cuando es transferencias entre bancos
               (GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::"Bank Account") THEN BEGIN
                BankAccount2.GET(GenJnlLine."Account No.");
                BankAccount2.TESTFIELD("Bank Account No.");

                BankAccount2."Bank Account No." := DELCHR(BankAccount2."Bank Account No.", '=', '-/., ');

                Lin_Body += FORMAT(BankAccount2."Bank Account No.") + FORMAT(Blanco, 20 - STRLEN(BankAccount2."Bank Account No."));
                Lin_Body += '1';
                IF STRPOS(ConfContab."LCY Code", 'USD') <> 0 THEN BEGIN
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
                        IF STRPOS(GenJnlLine."Currency Code", 'USD') <> 0 THEN
                            Lin_Body += '840'
                        ELSE
                            IF STRPOS(GenJnlLine."Currency Code", 'EU') <> 0 THEN
                                Lin_Body += '978'
                            ELSE
                                Lin_Body += '214'; //Moneda 214=RD$, 840=USD, 978=Euro

                    END
                    else
                        Lin_Body := '214';

                Lin_Body += BankAccount2."SWIFT Code";//Aqui debe tener el Identificador del banco + codigo ACH + Digito de chequeo
                Vendor."E-Mail" := BankAccount2."E-Mail";

                IF BankAccount2."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CC= Cuenta Corriente" THEN //Corriente
                    Lin_Body += '22'
                ELSE
                    IF BankAccount2."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" THEN //Ahorro
                        Lin_Body += '32'
                    ELSE
                        Lin_Body += '52'; //Tarjeta o Prestamo
            END
            ELSE BEGIN
                IF (VendorBank."Bank Account No." <> '') AND (VendorBank."DSNTipo Cuenta" <> BankAccount2."DSNTipo Cuenta"::"TJ= Tarjeta") THEN
                    Lin_Body += FORMAT(VendorBank."Bank Account No.") + FORMAT(Blanco, 20 - STRLEN(VendorBank."Bank Account No."))
                ELSE
                    IF VendorBank."DSNTipo Cuenta" <> BankAccount2."DSNTipo Cuenta"::"TJ= Tarjeta" THEN
                        ERROR(Err002, GenJnlLine."Account No." + ', ' + GenJnlLine.DSNBeneficiario)
                    ELSE
                        IF VendorBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"TJ= Tarjeta" THEN
                            Lin_Body += FORMAT(Blanco, 20);

                IF VendorBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CC= Cuenta Corriente" THEN //Corriente
                    Lin_Body += '1'
                ELSE
                    IF VendorBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" THEN //Ahorro
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

                    BcoACH.GET(VendorBank."DSNBanco RED ACH");
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

                        BcoACH.GET(VendorBank."DSNBanco RED ACH");
                        IF (GenJnlLine."Currency Code" = '') OR (BcoACH."Codigo Banco" = 'BPD') THEN BEGIN
                            Lin_Body += BcoACH."Codigo ACH";
                            Lin_Body += FORMAT(BcoACH."Digito Chequeo");
                        END
                        ELSE BEGIN
                            Lin_Body += '8' + COPYSTR(BcoACH."Codigo ACH", 2, 10);
                            Lin_Body += 'L';
                        END;
                    END;

                IF VendorBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CC= Cuenta Corriente" THEN //Corriente
                    Lin_Body += '22'
                ELSE
                    IF VendorBank."DSNTipo Cuenta" = BankAccount2."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" THEN //Ahorro
                        Lin_Body += '32'
                    ELSE
                        Lin_Body += '12';
            END;

            Lin_Body += FORMAT(GenJnlLine.Amount * 100, 13, '<integer,13><Filler Character,0>');

            // Se cambia por tipo doc y numero Lin_Body += FORMAT(Blanco,17,'<Text,17>');
            Vendor."VAT Registration No." := DELCHR(Vendor."VAT Registration No.", '=', '-');
            IF STRLEN(Vendor."VAT Registration No.") > 9 THEN
                Lin_Body += 'CE'
            ELSE
                Lin_Body += 'RN';

            Lin_Body += Format(GenJnlLine."VAT Registration No.", 15); //RNC

            Vendor.Name := Ascii2Ansi(Vendor.Name);
            Lin_Body += FORMAT(Vendor.Name, 35); //nombre beneficiario
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
            IF VendorBank."E-Mail" <> '' THEN
                Lin_Body += '1'
            ELSE
                Lin_Body += ' ';

            IF STRLEN(VendorBank."E-Mail") <= 40 THEN
                Lin_Body += FORMAT(VendorBank."E-Mail", 40);

            Lin_Body += FORMAT(Blanco, 12);
            Lin_Body += '00';

            Lin_Body += FORMAT(Blanco, 78);
            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));

            Contador := Contador + 1;

            Tracenumber := FORMAT(CURRENTDATETIME);
            Tracenumber := DELCHR(Tracenumber, '=', '._-:');
            ExportAmount := GenJnlLine.Amount;
            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;
            GenJnlLine."Check Transmitted" := TRUE;
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
        CRLF[1] := 13;
        CRLF[2] := 10;
        BankAccount.TESTFIELD("DSNIdentificador Empresa");

        //Leemos el diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);
        GenJnlLine.SETRANGE("Exported to Payment File", false);
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
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
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
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

            CLEAR(Vendor);
            CLEAR(Lin_Body);

            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Vendor THEN BEGIN
                Vendor.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                VendorBank.RESET;
                VendorBank.SETRANGE("Vendor No.", GenJnlLine."Account No.");
                VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                VendorBank.FINDFIRST;
                VendorBank.TESTFIELD("Bank Account No.");
                VendorBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(VendorBank."DSNBanco RED ACH");
                //      BcoACH.TESTFIELD("Ruta y Transito");
            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Vendor THEN BEGIN
                    Vendor.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    VendorBank.RESET;
                    VendorBank.SETRANGE("Vendor No.", GenJnlLine."Bal. Account No.");
                    VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    VendorBank.FINDFIRST;
                    VendorBank.TESTFIELD("Bank Account No.");
                    VendorBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(VendorBank."DSNBanco RED ACH");
                    //BcoACH.TESTFIELD("Ruta y Transito");
                END;
            BcoACH.GET(VendorBank."DSNBanco RED ACH");
            //Creo el detalle
            CLEAR(Lin_Body);
            VendorBank."Bank Account No." := DELCHR(VendorBank."Bank Account No.", '=', '-/., ');
            Lin_Body := VendorBank."Bank Account No." + ';'; //Cuenta del proveedor
            Lin_Body += BcoACH."Codigo Banco" + ';'; //Banco y ruta destino
            IF VendorBank."DSNTipo Cuenta" = 0 THEN //Corriente
                Lin_Body += 'CC'
            ELSE
                IF VendorBank."DSNTipo Cuenta" = 1 THEN //Ahorro
                    Lin_Body += 'CA'
                ELSE
                    Lin_Body += 'PR';
            GenJnlLine.DSNBeneficiario := Ascii2Ansi(Vendor.Name);
            GenJnlLine.DSNBeneficiario := DELCHR(GenJnlLine.DSNBeneficiario, '=', ';');
            Lin_Body += ';' + COPYSTR(GenJnlLine.DSNBeneficiario, 1, 22) + ';';
            Lin_Body += 'C;';
            Lin_Body += FORMAT(GenJnlLine.Amount, 0, '<Integer><Decimals,3>') + ';';
            SecuenciaTrans := INCSTR(SecuenciaTrans);
            Lin_Body += SecuenciaTrans + ';';
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DELCHR(GenJnlLine.Description, '=', ';');
            Lin_Body += COPYSTR(GenJnlLine.Description, 1, 80) + ';';
            Lin_Body += Vendor."E-Mail";
            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));
            Tracenumber := FORMAT(CURRENTDATETIME);
            Tracenumber := DELCHR(Tracenumber, '=', '._-:');
            ExportAmount := GenJnlLine.Amount;
            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;
            GenJnlLine."Check Transmitted" := TRUE;

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
        CRLF[1] := 13;
        CRLF[2] := 10;
        Blanco := ' ';
        CERO := '0';
        TotalGeneral := 0;
        PrimeraVez := TRUE;
        BankAccount.TESTFIELD("DSNIdentificador Empresa");

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);
        GenJnlLine.SETRANGE("Exported to Payment File", false);
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
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
        //NombreArchivo2 := NombreArchivo;

        TmpBlob.CREATEOUTSTREAM(StreamOut);

        //Leemos el Diario
        GenJnlLine.RESET;
        GenJnlLine.SETRANGE("Journal Template Name", CodDiario);
        GenJnlLine.SETRANGE("Journal Batch Name", SeccDiario);
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
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
            CLEAR(Vendor);
            CLEAR(Lin_Body);


            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Vendor THEN BEGIN
                Vendor.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                VendorBank.RESET;
                VendorBank.SETRANGE("Vendor No.", GenJnlLine."Account No.");
                VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                VendorBank.FINDFIRST;
                VendorBank.TESTFIELD("Bank Account No.");
                VendorBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(VendorBank."DSNBanco RED ACH");
                //      BcoACH.TESTFIELD("Ruta y Transito");
            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Vendor THEN BEGIN
                    Vendor.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    VendorBank.RESET;
                    VendorBank.SETRANGE("Vendor No.", GenJnlLine."Bal. Account No.");
                    VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    VendorBank.FINDFIRST;
                    VendorBank.TESTFIELD("Bank Account No.");
                    VendorBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(VendorBank."DSNBanco RED ACH");
                    //BcoACH.TESTFIELD("Ruta y Transito");
                END;
            BcoACH.GET(VendorBank."DSNBanco RED ACH");

            CLEAR(Lin_Body);
            VendorBank."Bank Account No." := DELCHR(VendorBank."Bank Account No.", '=', '-/., ');
            Lin_Body := VendorBank."Bank Account No." + ';'; //Cuenta del proveedor

            Lin_Body += BcoACH.Swift + ';'; //SWIFT
            IF VendorBank."DSNTipo Cuenta" = 0 THEN //Corriente
                Lin_Body += 'CC'
            ELSE
                IF VendorBank."DSNTipo Cuenta" = 1 THEN //Ahorro
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
            Lin_Body += Vendor."E-Mail" + ';';
            Vendor."VAT Registration No." := DELCHR(Vendor."VAT Registration No.", '=', '-');
            Lin_Body += Vendor."VAT Registration No.";


            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));


            ExportAmount := GenJnlLine.Amount;
            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;
            GenJnlLine."Check Transmitted" := TRUE;



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
        GenJnlLine.SETRANGE("Exported to Payment File", false);
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
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
        GenJnlLine.SETRANGE("Check Printed", FALSE);
        GenJnlLine.SETRANGE("Check Exported", FALSE);
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
            CLEAR(Vendor);
            CLEAR(Lin_Body);

            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::Vendor THEN BEGIN
                Vendor.GET(GenJnlLine."Account No.");
                BankAccount.GET(GenJnlLine."Bal. Account No.");
                VendorBank.RESET;
                VendorBank.SETRANGE("Vendor No.", GenJnlLine."Account No.");
                VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                VendorBank.FINDFIRST;
                VendorBank.TESTFIELD("Bank Account No.");
                VendorBank.TESTFIELD("DSNBanco RED ACH");
                BcoACH.GET(VendorBank."DSNBanco RED ACH");
                BcoACH.TESTFIELD("Codigo Banco");
            END
            ELSE
                IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Vendor THEN BEGIN
                    Vendor.GET(GenJnlLine."Bal. Account No.");
                    BankAccount.GET(GenJnlLine."Account No.");
                    VendorBank.RESET;
                    VendorBank.SETRANGE("Vendor No.", GenJnlLine."Bal. Account No.");
                    VendorBank.SETRANGE(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    VendorBank.FINDFIRST;
                    VendorBank.TESTFIELD("Bank Account No.");
                    VendorBank.TESTFIELD("DSNBanco RED ACH");
                    BcoACH.GET(VendorBank."DSNBanco RED ACH");
                    BcoACH.TESTFIELD("Codigo Banco");
                END;

            CLEAR(Lin_Body);
            IF BcoACH."Codigo Banco" <> 'BHD' THEN //Para tipo de trasaccion
                Lin_Body := '4;'
            ELSE
                Lin_Body := '1;';

            Lin_Body += BcoACH."Codigo Banco" + ';'; //Codigo del banco destino

            VendorBank."Bank Account No." := DELCHR(VendorBank."Bank Account No.", '=', '-/., ');
            IF VendorBank."DSNTipo Cuenta" = 0 THEN //Corriente
                Lin_Body += 'CC;'
            ELSE
                IF VendorBank."DSNTipo Cuenta" = 1 THEN //Ahorro
                    Lin_Body += 'CA;'
                ELSE
                    IF VendorBank."DSNTipo Cuenta" = 2 THEN //Tarjeta
                        Lin_Body += 'TJ;'
                    ELSE
                        Lin_Body += 'PR;'; //Prestamo

            Lin_Body += VendorBank."Bank Account No." + ';'; //Cuenta del proveedor
            Lin_Body += FORMAT(GenJnlLine.Amount, 0, '<Integer><Decimals,3>') + ';'; //Monto transaccion


            IF STRLEN(Vendor."VAT Registration No.") < 11 THEN //Tipo de documento
                Lin_Body += 'R;'
            ELSE
                IF STRLEN(Vendor."VAT Registration No.") = 11 THEN
                    Lin_Body += 'C;'
                ELSE
                    Lin_Body += 'P;';

            Lin_Body += DELCHR(Vendor."VAT Registration No.", '=', ' -;') + ';'; //Numero de documento


            GenJnlLine.DSNBeneficiario := DELCHR(GenJnlLine.DSNBeneficiario, '=', ';');
            Lin_Body += COPYSTR(GenJnlLine.DSNBeneficiario, 1, 22) + ';';
            Lin_Body += ';'; //Pais de nacimiento. Solo para pagos BCRD con tipo documento P
            Lin_Body += ';'; //Sexo. Solo para pagos BCRD con tipo documento P
            Lin_Body += ';'; //Tipo de registro. I= Inclusión (Cuando se desea inscribir un pago). C= - Cancelación (Cuando se desea cancelar un pago previamente inscrito y no combrado)


            Lin_Body += FORMAT(GenJnlLine."Line No.") + ';'; //Referencia
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DELCHR(GenJnlLine.Description, '=', ';');
            Lin_Body += COPYSTR(GenJnlLine.Description, 1, 80) + ';'; //Descripcion
            Lin_Body += VendorBank."E-Mail" + ';'; //Correo electronico beneficiario
            Lin_Body += ';'; //Campo Opcional 2

            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));

            Tracenumber := FORMAT(CURRENTDATETIME);
            Tracenumber := DELCHR(Tracenumber, '=', '._-:');
            ExportAmount := GenJnlLine.Amount;
            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;
            GenJnlLine."Check Transmitted" := TRUE;


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
        CRLF[1] := 13;
        CRLF[2] := 10;
        Blanco := ' ';
        CERO := '0';
        TotalGeneral := 0;
        BankAccount.TestField("DSNIdentificador Empresa");

        //Leemos el Diario
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);
        GenJnlLine.SETRANGE("Exported to Payment File", false);
        GenJnlLine.SetRange("Check Printed", false);
        GenJnlLine.SetRange("Check Exported", false);
        GenJnlLine.SetRange("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SetRange("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
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
        GenJnlLine.SetRange("Check Printed", false);
        GenJnlLine.SetRange("Check Exported", false);
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
            Clear(Vendor);
            Clear(Lin_Body);
            GenJnlLine.testfield(DSNBeneficiario);
            if BankAccount."DSNTipo Cuenta" = BankAccount."DSNTipo Cuenta"::"CA=Cuenta de Ahorro" then
                Lin_Body := 'CA'
            else
                Lin_Body := 'CC';

            if BankAccount."Currency Code" = '' then
                Lin_Body += ',DOP,'
            else
                Lin_Body += ',' + BankAccount."Currency Code" + ',';
            BankAccount."Bank Account No." := DelChr(BankAccount."Bank Account No.", '=', '-/., ');
            Lin_Body += BankAccount."Bank Account No." + ','; //Cuenta de origen

            if GenJnlLine."Account Type" = GenJnlLine."Account Type"::Vendor then begin
                Vendor.Get(GenJnlLine."Account No.");
                BankAccount.Get(GenJnlLine."Bal. Account No.");
                VendorBank.Reset;
                VendorBank.SetRange("Vendor No.", GenJnlLine."Account No.");
                VendorBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                VendorBank.FindFirst;
                VendorBank.TestField("Bank Account No.");
                VendorBank.TestField("DSNBanco RED ACH");
                BcoACH.Get(VendorBank."DSNBanco RED ACH");

            end
            else
                if GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Vendor then begin
                    Vendor.Get(GenJnlLine."Bal. Account No.");
                    BankAccount.Get(GenJnlLine."Account No.");
                    VendorBank.Reset;
                    VendorBank.SetRange("Vendor No.", GenJnlLine."Bal. Account No.");
                    VendorBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    VendorBank.FindFirst;
                    VendorBank.TestField("Bank Account No.");
                    VendorBank.TestField("DSNBanco RED ACH");
                    BcoACH.Get(VendorBank."DSNBanco RED ACH");

                end;

            Lin_Body += BcoACH."Codigo ACH" + ','; //Banco y ruta destino

            //DSNTipo Cuenta ==> AH= ahorro, CC= Corriente, TC = Tarjeta de crédito, PR = Préstamos
            if (VendorBank."Bank Account No." <> '') and (VendorBank."DSNTipo Cuenta" <> 2) then
                Lin_Body += VendorBank."Bank Account No."
            else
                if VendorBank."DSNTipo Cuenta" <> 2 then
                    Error(Err002, GenJnlLine."Account No." + ', ' + GenJnlLine.DSNBeneficiario)
                else
                    if VendorBank."DSNTipo Cuenta" = 2 then
                        Lin_Body += Format(Blanco, 20);
            Lin_Body += ',';
            if VendorBank."DSNTipo Cuenta" = 0 then //Corriente
                Lin_Body += 'CC'
            else
                Lin_Body += 'CA';

            VendorBank."Bank Account No." := DelChr(VendorBank."Bank Account No.", '=', '-/., ');

            Lin_Body += ',';
            Lin_Body += Format(GenJnlLine.Amount * 100, 13, '<integer,13><Filler Character,0>') + ',';
            GenJnlLine.DSNBeneficiario := DelChr(GenJnlLine.DSNBeneficiario, '=', ',');
            Lin_Body += CopyStr(GenJnlLine.DSNBeneficiario, 1, 22) + ',';
            Vendor.TestField("VAT Registration No.");
            if StrLen(DelChr(Vendor."VAT Registration No.", '=', ' -')) = 9 then
                Lin_Body += 'RNC'
            else
                if StrLen(DelChr(Vendor."VAT Registration No.", '=', ' -')) = 11 then
                    Lin_Body += 'Cedula'
                else
                    Lin_Body += 'Pasaporte,';
            Lin_Body += RNC + ',';
            GenJnlLine.Description := Ascii2Ansi(GenJnlLine.Description);
            GenJnlLine.Description := DelChr(GenJnlLine.Description, '=', ',');
            Lin_Body += Format(CopyStr(GenJnlLine.Description, 1, 55), 55);
            StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));


            GenJnlLine."Check Printed" := TRUE;
            GenJnlLine."Check Exported" := TRUE;
            GenJnlLine."Check Transmitted" := TRUE;
            GenJnlLine."Exported to Payment File" := TRUE;
            GenJnlLine.MODIFY;
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
        GenJnlLine.SETRANGE("Exported to Payment File", false);
        GenJnlLine.SetRange("Check Printed", false);
        GenJnlLine.SetRange("Check Exported", false);
        GenJnlLine.SetRange("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.SetRange("Bank Payment Type", GenJnlLine."Bank Payment Type"::"Electronic Payment");
        GenJnlLine.SetFilter(Amount, '<>%1', 0);
        GenJnlLine.FindFirst;

        BankAccount.Modify;
        NombreArchivo2 := NombreArchivo;

        //Leemos el Diario
        GenJnlLine.Reset;
        GenJnlLine.SetRange("Journal Template Name", CodDiario);
        GenJnlLine.SetRange("Journal Batch Name", SeccDiario);
        GenJnlLine.SetRange("Check Printed", false);
        GenJnlLine.SetRange("Check Exported", false);
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
            Clear(Vendor);
            Clear(Lin_Body);
            Contador := Contador + 1;

            if GenJnlLine."Account Type" = GenJnlLine."Account Type"::Vendor then begin
                Vendor.Get(GenJnlLine."Account No.");
                BankAccount.Get(GenJnlLine."Bal. Account No.");
                VendorBank.Reset;
                VendorBank.SetRange("Vendor No.", GenJnlLine."Account No.");
                VendorBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                CodBco := GenJnlLine."Bal. Account No.";
                VendorBank.FindFirst;
                VendorBank.TestField("Bank Account No.");
                VendorBank.TestField("DSNBanco RED ACH");
                BcoACH.Get(VendorBank."DSNBanco RED ACH");
                //      BcoACH.TESTFIELD("Ruta y Transito");
            end
            else
                if GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Vendor then begin
                    Vendor.Get(GenJnlLine."Bal. Account No.");
                    BankAccount.Get(GenJnlLine."Account No.");
                    VendorBank.Reset;
                    VendorBank.SetRange("Vendor No.", GenJnlLine."Bal. Account No.");
                    VendorBank.SetRange(Code, GenJnlLine."Recipient Bank Account");
                    CodBco := GenJnlLine."Account No.";
                    VendorBank.FindFirst;
                    VendorBank.TestField("Bank Account No.");
                    VendorBank.TestField("DSNBanco RED ACH");
                    BcoACH.Get(VendorBank."DSNBanco RED ACH");
                    //      BcoACH.TESTFIELD("Ruta y Transito");
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
                if GenJnlLine."Account Type" = GenJnlLine."Account Type"::Vendor then
                    Lin_Body += Format(DelChr(Vendor."VAT Registration No.", '=', ' .-'))
                else
                    if GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::Vendor then
                        Lin_Body += Format(DelChr(Vendor."VAT Registration No.", '=', ' .-'))
                    else
                        Lin_Body += Format(Counter, 0, '<Integer>');
                Lin_Body += ',';
                Lin_Body += VendorBank."SWIFT Code";
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
                StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));
            end
            else begin
                Clear(Lin_Body);
                Lin_Body := Format(CopyStr(GenJnlLine.DSNBeneficiario, 1, 32), 32);
                Lin_Body += ',';
                Counter += 1;
                Lin_Body += Format(Contador, 0, '<Integer>');
                Lin_Body += ',';
                Lin_Body += VendorBank."SWIFT Code";
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
                StreamOut.WRITETEXT(Lin_Body + FORMAT(CRLF[1]) + FORMAT(CRLF[2]));
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
        VendorLedgerEntry: record "Vendor Ledger Entry";
    begin
        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetCurrentKey("Vendor No.", "Posting Date", "Applies-to ID");
        VendorLedgerEntry.SetRange("Vendor No.", GenJnlLine."Account No.");
        if GenJnlLine."Applies-to ID" <> '' then
            VendorLedgerEntry.SetRange("Applies-to ID", GenJnlLine."Applies-to ID")
        else
            VendorLedgerEntry.SetRange("Applies-to ID", GenJnlLine."Document No.");
        if not VendorLedgerEntry.FindFirst() then
            VendorLedgerEntry.init;

        if strlen(VendorLedgerEntry."External Document No.") < 13 then
            Lin_Body += copystr(format(VendorLedgerEntry."External Document No.") + PADSTR(Blanco, 12 - STRLEN(format(VendorLedgerEntry."External Document No."))), 1, 12) //numero de referencia
        else
            Lin_Body += copystr(format(VendorLedgerEntry."External Document No."), 1, 12); //numero de referencia
    end;

    local procedure elimina() //Procedure para poner linea en rojo cuando haya error en respuesta de banco
    var
        PaymentJnlError: Record "Payment Jnl. Export Error Text";
    begin
        if PaymentJnlError.FindSet() then
            PaymentJnlError.DeleteAll();

    end;

    [Scope('Cloud')]
    procedure ImportBankFile(var GeneralJournalLine: Record "Gen. Journal Line")
    var
        Respuestasbancos: Record "Respuestas Bancos";
        CodRechazobancos: Record CodigoRechazoBanco;
        NoLin: Integer;
        PaymentJnlError: Record "Payment Jnl. Export Error Text";

    begin
        Respuestasbancos.RESET;
        Respuestasbancos.DELETEALL;

        GenJnlLine.RESET;
        GenJnlLine.CopyFilters(GeneralJournalLine);
        GenJnlLine.FINDFIRST;

        IF GenJnlLine."Bal. Account Type" = GenJnlLine."Bal. Account Type"::"Bank Account" THEN
            BankAccount.GET(GenJnlLine."Bal. Account No.")
        ELSE
            IF GenJnlLine."Account Type" = GenJnlLine."Account Type"::"Bank Account" THEN
                BankAccount.GET(GenJnlLine."Account No.");

        BankAccount.TESTFIELD(DSNFormato);
        BankAccount.TESTFIELD("DSNXMLPort arch. confirm. bco");
        UPLOADINTOSTREAM('', '', '', NombreArchivo, StreamIn);


        XMLPORT.IMPORT(BankAccount."DSNXMLPort arch. confirm. bco", StreamIn);


        Respuestasbancos.RESET;
        BcoACH.Get(BankAccount.DSNFormato);
        Respuestasbancos.SetRange("ID Banco", BcoACH."Codigo Banco");

        Respuestasbancos.FIND('-');
        REPEAT
            IF (STRPOS(Respuestasbancos."Cod retorno", 'R') <> 0) AND (STRPOS(Respuestasbancos."Cod razon", 'R') <> 0) THEN BEGIN
                //EVALUATE(NoLin,Respuestasbancos."No identificacion");

                GenJnlLine.RESET;
                GenJnlLine.CopyFilters(GeneralJournalLine);
                GenJnlLine.FindSet();
                GenJnlLine.FINDFIRST;

                CodRechazobancos.RESET;
                CodRechazobancos.SETRANGE("Codigo Banco", BcoACH."Codigo Banco");
                CodRechazobancos.SETRANGE("Codigo razon", Respuestasbancos."Cod razon");
                CodRechazobancos.SETRANGE("Codigo retorno", Respuestasbancos."Cod retorno");
                CodRechazobancos.FINDFIRST;

                GenJnlLine."DSNPayment Related Information" := CodRechazobancos.Descripcion;
                GenJnlLine."Check Exported" := FALSE;
                GenJnlLine."Check Printed" := FALSE;
                GenJnlLine."Check Transmitted" := FALSE;
                GenJnlLine."Exported to Payment File" := FALSE;
                GenJnlLine."DSNPago elect. rechazado" := TRUE;

                PaymentJnlError.SetRange("Journal Template Name", GenJnlLine."Journal Template Name");
                PaymentJnlError.SetRange("Journal Batch Name", GenJnlLine."Journal Batch Name");
                PaymentJnlError.SetRange("Document No.", GenJnlLine."Document No.");
                PaymentJnlError.SetRange("Journal Line No.", GenJnlLine."Line No.");
                if PaymentJnlError.FindLast() then
                    PaymentJnlError."Line No." += 1;

                PaymentJnlError."Journal Template Name" := GenJnlLine."Journal Template Name";
                PaymentJnlError."Journal Batch Name" := GenJnlLine."Journal Batch Name";
                PaymentJnlError."Document No." := GenJnlLine."Document No.";
                PaymentJnlError."Journal Line No." := GenJnlLine."Line No.";

                PaymentJnlError.Insert;
                GenJnlLine.MODIFY;


            END;
        UNTIL Respuestasbancos.NEXT = 0;
    end;

    [Scope('Cloud')]
    procedure Ascii2Ansi(_Text: Text[250]): Text[250]
    begin
        MakeVars();
        exit(ConvertStr(_Text, AsciiStr, AnsiStr));
    end;

    local procedure MakeVars()
    begin
        AsciiStr := 'áéíóúñÑÁÉÍÓÚÜü';
        AnsiStr := 'aeiounNAEIOUUu';
    end;

}