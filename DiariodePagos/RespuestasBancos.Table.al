table 60106 "Respuestas Bancos"
{
    DataClassification = ToBeClassified;
    
    fields
    {
        field(1;"ID Banco"; Code[20])
        {
            Caption = 'ID Banco';
        }
        field(2; "Texto1"; Text[100])
        {
            Caption = 'Texto1';
        }
        field(3; "No identificacion"; Text[30])
        {
            Caption = 'No identificacion';
        }
        field(4; "Texto2"; Text[100])
        {
            Caption = 'Texto2';
        }
        field(5; "Numero autorizacion"; Text[30])
        {
            Caption = 'Numero autorizacion'; 
        }
        field(6; "Cod retorno rem BPD"; Code[3])
        {
            Caption = 'Cod retorno rem BPD';
        }
        field(7; "Cod retorno"; code[3])
        {
            Caption = 'Cod retorno';
        }
        field(8; "Cod razon"; Code[3])
        {
            Caption = 'Cod razon';
        }
    }
    
    keys
    {
        key(key1; "ID Banco", "No identificacion")
        {
            Clustered = true;
        }
    }
    
}