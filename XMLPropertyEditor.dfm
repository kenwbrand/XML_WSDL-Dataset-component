object frm_XMLEDIT: Tfrm_XMLEDIT
  Left = 0
  Top = 0
  Width = 433
  Height = 388
  Caption = 'XML List Editor'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object SM_XMLEdit: TSynMemo
    Left = 0
    Top = 0
    Width = 425
    Height = 328
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Courier New'
    Font.Style = []
    TabOrder = 0
    Gutter.Font.Charset = DEFAULT_CHARSET
    Gutter.Font.Color = clWindowText
    Gutter.Font.Height = -11
    Gutter.Font.Name = 'Courier New'
    Gutter.Font.Style = []
    Gutter.Visible = False
    Highlighter = SynXMLSyn1
    WordWrap = True
  end
  object Panel1: TPanel
    Left = 0
    Top = 328
    Width = 425
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      425
      33)
    object Panel2: TPanel
      Left = 108
      Top = 0
      Width = 209
      Height = 33
      Anchors = []
      BevelOuter = bvNone
      TabOrder = 0
      DesignSize = (
        209
        33)
      object btn_ok: TButton
        Left = 19
        Top = 6
        Width = 75
        Height = 25
        Anchors = []
        Caption = 'OK'
        ModalResult = 1
        TabOrder = 0
      end
      object btn_cancel: TButton
        Left = 115
        Top = 6
        Width = 75
        Height = 25
        Anchors = []
        Caption = 'Cancel'
        ModalResult = 2
        TabOrder = 1
      end
    end
  end
  object SynXMLSyn1: TSynXMLSyn
    WantBracesParsed = False
    Left = 392
    Top = 8
  end
end
