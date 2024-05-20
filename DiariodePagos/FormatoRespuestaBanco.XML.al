xmlport 60100 "Formato respuesta BPD"
{
    Direction = Import;
    Format = FixedText;
    UseRequestPage = false;
    schema
    {
        textelement(Respuesta)
        {
            tableelement("Respuestas bancos"; "Respuestas bancos")
            {
                AutoSave = false;
                XmlName = 'FormatoBPD';
                textelement(texto)
                {
                    Width = 80;
                }
                textelement(No_Identificacion)
                {
                    Width = 15;
                }
                textelement(texto2)
                {
                    Width = 146;
                }
                textelement(NumAuth)
                {
                    Width = 15;
                }
                textelement(CodRetornoRem)
                {
                    Width = 3;
                }
                textelement(CodRetorno)
                {
                    Width = 3;
                }
                textelement(CodRazon)
                {
                    Width = 3;
                }
                trigger OnBeforeInsertRecord()
                begin
                    RespBanco.Init;
                    RespBanco."ID Banco" := 'BPD';
                    RespBanco."No identificacion" := No_Identificacion;
                    RespBanco.Texto1 := texto;
                    RespBanco.Texto2 := texto2;
                    RespBanco."Numero autorizacion" := NumAuth;
                    RespBanco."Cod retorno rem BPD" := CodRetornoRem;
                    RespBanco."Cod retorno" := CodRetorno;
                    RespBanco."Cod razon" := CodRazon;
                    RespBanco.Insert;
                end;
            }
        }
    }

    requestpage
    {

        layout
        {
        }

        actions
        {
        }
    }

    trigger OnPreXmlPort()
    begin
        RespBanco.DeleteAll;
    end;

    var
        RespBanco: Record "Respuestas bancos";

}

