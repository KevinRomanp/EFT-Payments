pageextension 60102 DSNCashReceiptJournalPageExt extends "Cash Receipt Journal"
{
    layout
    {
        addafter("Account No.")
        {
            field("DSNRecipient Bank Account"; Rec."Recipient Bank Account")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the bank account that the amount will be transferred to after it has been exported from the payment journal.';
            }
            field("DSNBeneficiario"; rec.DSNBeneficiario)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Beneficiary field.';
            }
        }

    }
    actions
    {
        addlast("F&unctions")
        {
            action("Generate EFT File")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Generate EFT file';
                Image = ExportElectronicDocument;


                trigger OnAction()
                var
                    PagosElectronicos: Codeunit DiarioRecepcionEfectivo;




                begin

                    PagosElectronicos.FormatoPagoClientes(Rec."Journal Template Name", Rec."Journal Batch Name")

                end;

            }
            action(AnularTransmitido)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Void EFT';
                Ellipsis = true;
                Image = VoidElectronicDocument;
                ToolTip = 'Void the exported electronic payment file.';

                trigger OnAction()
                var
                    GenJnlLine: Record "Gen. Journal Line";
                    PagosElectronicos: Codeunit DiarioRecepcionEfectivo;
                begin
                    GenJnlLine.CopyFilters(Rec);
                    if GenJnlLine.FindFirst() then begin
                        PagosElectronicos.AnularTransmitido(GenJnlLine);
                        GenJnlLine.VoidPaymentFile();
                    end;
                end;
            }
        }
    }

}