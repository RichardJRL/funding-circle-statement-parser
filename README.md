# funding-circle-statement-parser
## Summary
Perl program to create a summary of transactions from Funding Circle (www.fundingcircle.com) monthly transaction statements that are provided to lending account holders.
## License
The contents of the repository RichardJRL/funding-circle-statement-parser are licensed under the GNU General Public License v3.0
## Abstract
The program takes a lending account holder's monthly transaction statements as input, parses them and calculates monthy sum totals for each different transaction category identified within the statements. The program output is either a 'pretty' summary table or a comma separated value (csv) table which can be imported into a spreadsheet for further analysis.

When more than one statement is given as input an additional summary table or row in the csv table is provided as output giving the sum totals for each transaction category over the entire date range found in the statement files. 
## Transaction Categories
The following transaction categories are summarised by the program:
- **Interest repayment:** Scheduled loan interest repayments from borrowers
- **Early interest repayment:** Unscheduled (early) loan interest repayments from borrowers
- **Principal repayment:** Scheduled loan principal repayments from borrowers
- **Early principal repayment:** Unscheduled (early) loan principal repayments from borrowers
- **Principal recovery repayment:** Loan principal payments from borrowers who have defaulted on their loans (Recovery of capital from bad debts)
- **New loans made:** Money lent by the account holder to new borrowers
- **Fees:** Fees paid to Funding Circle
- **Deposits:** Money added to Funding Circle by the account holder from their own bank account
- **Withdrawals:** Money withdrawn from Funding Circle by the account holder to their own bank account
- **Principal credit (old):** For loans sold on the secondary market before 2 December 2019 by the account holder to other borrowers (e.g. by using "Access Funds"), this is the value of the remaining loan principal of loans sold
- **Interest credit (old):** For loans sold on the secondary market  before 2 December 2019 by the account holder to other borrowers (e.g. by using "Access Funds"), this is the value of the interest that has accrued between the last received interest payment and the loan sale date. It is paid by the purchaser of the loan to the account holder. (The purchaser later receives the full month's interest from the borrower as scheduled.)
- **Principal debit (old):** For loans purchased the secondary market before 2 December 2019, this is the value of the remaining loan capital and is paid by the account holder to the seller.
- **Interest debit (old):** For loans purchased the secondary market before 2 December 2019, this is the value of the interest that has accrued between the last received interest payment and the loan purchase date and is paid by the account holder to the seller. (The account holder later receives the full month's interest from the borrower as scheduled.)
- **Historical Delta (old):** A historical feature of Funding Circle related to promotions. No longer used, replaced with the transfer payment. (NB:** if it ever appears, the program assumes it will always be a debit.)
- **Historical Fees (old):** A historical feature of Funding Circle related to promotions. No longer used, replaced with the transfer payment. (NB: if it ever appears, the program assumes it will always be a debit.)
- **Principal debit (new):** For loans purchased the secondary market on or after 2 December 2019, this is the value of the remaining loan capital and is paid by the account holder to the seller.
- **Interest debit (new):** For loans purchased the secondary market on or after 2 December 2019, this is the value of the interest that has accrued between the last received interest payment and the loan purchase date and is paid by the account holder to the seller. (The account holder later receives the full month's interest from the borrower as scheduled.)
- **Transfer payment credit (new):** For loans purchased the secondary market on or after 2 December 2019, this is the 1.25% fee paid by the seller of the loan to the purchaser.
## Derived Categories
- **Net interest:** Derived using the same calculation that Funding Circle use to display "INTEREST" displayed on their website's Summary page: This is 'Net Interest'  = 'Interest repayment' + 'Early interest repayment' + 'Interest credit' - 'Interest debit'
## Command Line Arguments
Either or both of the output format specifiers are required
- `--csv` for a spreadsheet-compatible table
- `--summary` for a 'pretty' human readable table

Optionally, a string to correctly identify 'Deposits' transactions is required if they appear in the Funding Circle statements with your name or BACS transfer reference instead of the generic 'TRANSFERIN' description. If you have made deposits from multiple different accounts which appear with different identifying names, the additional names can be entered as a comma separated list without whitespace. The name(s) you need to enter can be easily identified from any error messages the program prints.
- `--name="NameOne[,NameTwo,NameThree,...]"`

AND one or more Funding Circle monthly transaction statement csv files with the filename unchanged from it's original format of 'statement_2020-01_2020-02-01_12-34-56.csv'.

Either paths to individual files can be provided, or shell globbing can be taken advantage of to select multiple files on a single path, or the path of a directory containing one or more statement files can be given.

Program output is sent to STDOUT, to save to a file use the redirection operator > or >> followed by your chosen filename. Alternatively pipe the program output to the `tee` utility.
## Funding Circle Statement File Format
The name of the file is composed of statement\_[STATEMENTDATE]\_[DOWNLOADDATE]\_[DOWNLOADTIME].csv where
- STATEMENTDATE is given as YYYY-MM
- DOWNLOADDATE is given as YYYY-MM-DD
- DOWNLOADTIME iis given as hh-mm-ss

If the file has been renamed and no longer has this format, the program will probably not recognise it.
## Sample Commands
`/usr/local/bin/perl funding_circle_statement_parser.pl --summary /path/to/statement_2020-01_2020-02-01_12-34-56.csv > FC_summarytable.csv`

`./funding_circle_statement_parser.pl --csv /path/to/statement_folder`
## Sample Output
`--summary` style of output (requires a wide screen or viewing in a spreadsheet program):

```
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~ January 2020 Statement ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Summary of all transaction types from Wednesday 01 January to Monday 27 January

WARNING: Statement may not contain all transactions for the whole calendar month
         Statement was downloaded at 17:02:17 on 27 January 2020 and
         contains no recorded transactions after 27 January 2020.

        Interest repayment            £  13.20 from 140 transactions
        Early interest repayment      £   0.16 from   4 transactions
        Principal repayment           £  62.12 from 140 transactions
        Early principal repayment     £  21.84 from   5 transactions
        Principal recovery repayment  £   0.32 from   1 transactions
        New loans made                £ -20.00 from   2 transactions
        Fees                          £  -1.45 from 131 transactions
        Deposits                      £  10.00 from   1 transactions
        Withdrawals                   £ -61.95 from   2 transactions
        Principal credit              £   0.00 from   0 transactions
        Interest credit               £   0.00 from   0 transactions
        Principal debit               £   0.00 from   0 transactions
        Interest debit                £   0.00 from   0 transactions

```
`--csv` style of output:

```
    Date, Interest repayment, Early interest repayment, Principal repayment, Early principal repayment, Principal recovery repayment, New loans made,  Fees, Deposits, Withdrawals, Principal credit, Interest credit, Principal debit, Interest debit
 2019-10,              40.29,                     0.46,              134.63,                     48.07,                         0.37,           0.00, -4.53,     0.00,    -3625.00,          3009.57,            9.80,            0.00,           0.00
 2019-11,              15.79,                     0.23,               73.51,                     26.51,                         0.31,           0.00, -1.87,     0.00,     -125.00,             0.00,            0.00,            0.00,           0.00
 2019-12,              14.35,                     0.03,               71.98,                     10.00,                         0.31,           0.00, -1.67,     0.00,     -135.00,             0.00,            0.00,            0.00,           0.00
 Totals ,              70.43,                     0.72,              280.12,                     84.58,                         0.99,           0.00, -8.07,     0.00,    -3885.00,          3009.57,            9.80,            0.00,           0.00
 ```
## Compatibility
The program has been tested with perl 5, version 30, subversion 1 (v5.30.1) built for x86_64-linux-thread-multi on OpenSuSE Tumbleweed