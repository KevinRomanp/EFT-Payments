page 60100 CodigoRechazoBanco
{
    Caption = 'Codigo Rechazo Banco';
    PageType = List;
    UsageCategory = Lists;
    ApplicationArea = admin;
    SourceTable = CodigoRechazoBanco;
    
    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Codigo Banco"; rec."Codigo Banco")
                {
                    ApplicationArea = All;
                }
                field("Codigo Razon";Rec."Codigo Razon")
                {
                    ApplicationArea = all;
                }
                field("Codigo retorno";Rec."Codigo retorno")
                {
                    ApplicationArea = all;
                }
                field(Descripcion;Rec.Descripcion)
                {
                    ApplicationArea = all;
                }
                
            }
        }
        area(Factboxes)
        {
            
        }
    }
    
    actions
    {
    }
}