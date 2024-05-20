table 60105 CodigoRechazoBanco
{
    DataClassification = ToBeClassified;
    
    fields
    {
        field(1;"Codigo Banco"; Code[4])
        {
            Caption = 'Bank code';
            DataClassification = ToBeClassified;
        }
        field(2; "Codigo Razon"; Code[5])
        {
            Caption = 'Reason code';
        }
        field(3; "Codigo retorno"; Code[5])
        {
            Caption = 'Return code';

        }
        field(4; Descripcion; Text[150])
        {
            Caption = 'Description';
        }
        
    }
    
    keys
    {
        key(PK; "Codigo Banco", "Codigo retorno","Codigo Razon")
        {
            Clustered = true;
        }
    }
    
}