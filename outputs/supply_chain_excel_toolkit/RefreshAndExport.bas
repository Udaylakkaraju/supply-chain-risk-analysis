Attribute VB_Name = "RefreshAndExport"
Option Explicit

Public Sub RefreshDataAndExportExceptions()
    Dim reportSheet As Worksheet
    Dim exportBook As Workbook
    Dim exportPath As String

    On Error GoTo CleanUp
    Application.ScreenUpdating = False
    Application.StatusBar = "Refreshing supply-chain data..."
    ThisWorkbook.RefreshAll
    Application.CalculateUntilAsyncQueriesDone
    Application.CalculateFull

    Set reportSheet = ThisWorkbook.Worksheets("Exception Report")
    exportPath = ThisWorkbook.Path & Application.PathSeparator & _
        "Exception_Report_" & Format(Now, "yyyymmdd_hhnnss") & ".xlsx"

    Set exportBook = Workbooks.Add(xlWBATWorksheet)
    reportSheet.UsedRange.Copy
    With exportBook.Worksheets(1).Range("A1")
        .PasteSpecial xlPasteValuesAndNumberFormats
        .PasteSpecial xlPasteFormats
    End With
    Application.CutCopyMode = False
    exportBook.Worksheets(1).Name = "Exception Report"
    exportBook.SaveAs Filename:=exportPath, FileFormat:=xlOpenXMLWorkbook
    exportBook.Close SaveChanges:=False

    MsgBox "Refresh complete. Exception report exported to:" & vbCrLf & exportPath, vbInformation

CleanUp:
    Application.StatusBar = False
    Application.ScreenUpdating = True
    If Err.Number <> 0 Then MsgBox "Refresh/export stopped: " & Err.Description, vbExclamation
End Sub
