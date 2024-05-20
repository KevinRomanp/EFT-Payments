pageextension 60101 ExportEFTFilePageExtension extends "Payment Journal"
{
    layout
    { 
        
    }
    
    actions
    {
        
        
        modify (VoidPayments)
        {
            Visible = false;
        }
        modify (TransmitPayments)
        {
            Visible = false;
        }
        modify (ExportPaymentsToFile)
        {
            Visible = false;
        }

        addfirst("Electronic Payments")
        {
            action("Generate EFT File")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Generate EFT File';
                Image = ExportElectronicDocument; 
                Promoted = true;
                PromotedCategory = Category4;       
            
            
            trigger OnAction()
            var 
            PagosElectronicos : Codeunit "Genera Formatos  E. Nomina RD"; 
            GenJnlLine: Record "Gen. Journal Line";
            FirstTime: Boolean;
            BancoAnt: Code[20];  
            BankAccount: Record "Bank Account";
            BcoACH: Record DSNBancosACH;
            bankpaymentoption : label'Standard, Instant Payment, Cancel';
            seleccion:Integer;            
            begin
                
                FirstTime := true;
                GenJnlLine.Reset();
                GenJnlLine.SetRange("Journal Template Name", rec."Journal Template Name");
                GenJnlLine.SetRange("Journal Batch Name", rec."Journal Batch Name");
                
                GenJnlLine.FindSet;
                repeat
                    if FirstTime then begin
                        FirstTime := false;
                        BancoAnt := GenJnlLine."Bal. Account No.";
                        BankAccount.Get(BancoAnt);
                    end;
                    if BancoAnt <> GenJnlLine."Bal. Account No." then
                    GenJnlLine.Testfield("Document No.");
                until GenJnlLine.Next = 0;

                
                    
                    BankAccount.TestField(DSNFormato); //Verifico que el campo este lleno
                    BcoACH.get(BankAccount.DSNFormato); //Busco en ACH el identificador del banco
                    BcoACH.TestField("Codigo Banco"); //Verifico que este lleno

                    if BcoACH."Codigo Banco" = 'BHD' then 
                    Seleccion := STRMENU(BankPaymentOption,3);
                    PagosElectronicos.FormatoPagoProveedores(Rec."Journal Template Name", Rec."Journal Batch Name", seleccion);
                    /*
                    GenJnlLine."Exported to Payment File" := TRUE;
                    GenJnlLine."Check Transmitted" := TRUE;
                    GenJnlLine."Check Printed" := TRUE;
                    if GenJnlLine.FindSet(true) then 
                     GenJnlLine.Modify;
                     */                                              
            end;
            
            }
            action(AnularTransmitido)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Void EFT';
                Ellipsis = true;
                Image = VoidElectronicDocument;
                ToolTip = 'Void the exported electronic payment file.';
                Promoted = true;
                PromotedCategory = Category4;  

                trigger OnAction()
                var
                GenJnlLine: Record "Gen. Journal Line";
                PagosElectronicos : Codeunit "Genera Formatos  E. Nomina RD"; 
                begin
                GenJnlLine.CopyFilters(Rec);
                if GenJnlLine.FindFirst() then
                    begin
                        PagosElectronicos.AnularTransmitido(GenJnlLine);
                        GenJnlLine.VoidPaymentFile();
                    end;
                end;
            }
            action(ImportarArchivoBanco)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Import Bank File';
                Ellipsis = true;
                Image = Import;
                ToolTip = 'Import bank conciliation electronic payment file.';
                Promoted = true;
                PromotedCategory = Category4;  
                
                trigger OnAction()
                var
                GenJnlLine: Record "Gen. Journal Line";
                PagosElectronicos : Codeunit "Genera Formatos  E. Nomina RD"; 
                begin
                GenJnlLine.CopyFilters(Rec);
                if GenJnlLine.FindFirst() then
                    begin
                        PagosElectronicos.ImportBankFile(GenJnlLine);
                    end
                end;
            }       
        }
    }    
      
}