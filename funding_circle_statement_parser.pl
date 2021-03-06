#!/usr/bin/perl

use strict;
use warnings;
use autodie;
use Data::Dumper;
use File::Spec;
use Time::Piece;

# array to hold all information parsed from all statement files found in the command line arguments
my @statementResults;

# variables to hold command line argument values
my $claCsv = 0;
my $claSummary = 0;
my $claName = 'unset';
my $claErrors = 0;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# subroutine to create the data structure which  holds the results for a statement
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Arguments:
# None
# Return Value:
# An empty data structure which can hold all details of a statement file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub createStatementDataStructure {
    # create the required data structures for storing information parsed from a statement file
    
    # all the different categories of transaction available in a statement
    # comprehensive descriptions of each transaction category are included in the README.md file
    # The primary key of each hash of hashes is actually the pretty display name of the transaction category to be shown in the results
    # searchString is the string or regexp that can be searched for to uniquely identify a particular transaction category in the statement 
    # column is the data column in the csv file to parse the transaction value from. Valid values are 2 for a credit or 3 for a debit
    # index is the position the transaction category will occupy in the table of results. Each index value should be a unique positive integer.
    # visible is a boolean value for whether or not the transaction category will be shown in the results: 1=show, 0=hide
    # derivedGroup is a positive integer value for grouping transaction categories together for the purposes of calulating derived, net category totals
    # and the derived transaction category should have the equal and opposite (negative) integer. 0 for no associated derived group.
    my %transactionCategories = (
        'Interest repayment' => {
            searchString  => "Interest repayment",
            column => 2,
            index => 0,
            visible => 1,
            derivedGroup => 1,
        },
        'Early interest repayment' => {
            searchString => "Early interest repayment",
            column => 2,
            index => 1,
            visible => 1,
            derivedGroup => 1,
        },
        'Interest recovery repayment' => {
            searchString => "Interest recovery repayment",
            column => 2,
            index => 2,
            visible => 1,
            derivedGroup => 1,
        },
        'Principal repayment' => {
            searchString => "Principal repayment",
            column => 2,
            index => 3,
            visible => 1,
            derivedGroup => 0,
        },
        'Early principal repayment' => {
            searchString => "Early principal repayment",
            column => 2,
            index => 4,
            visible => 1,
            derivedGroup => 0,
        },
        'Principal recovery repayment' => {
            searchString => "Principal recovery repayment",
            column => 2,
            index => 5,
            visible => 1,
            derivedGroup => 0,
        },
        'New loans made' => {
            searchString => "Loan offer",
            column => 3,
            index => 6,
            visible => 1,
            derivedGroup => 0,
        },
        'Fees' => {
            searchString => "Servicing fee",
            column => 3,
            index => 7,
            visible => 1,
            derivedGroup => 0,
        },
        'Deposits' => {
            searchString => "TRANSFERIN|$claName",
            column => 2,
            index => 8,
            visible => 1,
            derivedGroup => 0,
        },
        'Withdrawals' => {
            searchString => "Withdrawal",
            column => 3,
            index => 9,
            visible => 1,
            derivedGroup => 0,
        },
        # processing matching lines containing 'Loan Part ID [0-9]+ : Principal...' requires more complex regexps.
        # The transaction description column of this line contains four transaction categories that will be impossible to differentiate if two
        # or more are both credits, or both debits, AND have the same value.
        # Most commonly this means that a Fee cannot be distinguished from a Delta as whichever one appears (and I cannot tell which) is always 
        # recorded in the debit column as a value 0.0 but the value for both in the transaction description column is also recorded as 0.00 
        # If either a Fee or a Delta is found to be NOT a debit then a regexp that can differentiate between them can be constructed, but until 
        # then it is ambiguous and EITHER all Fees OR all Delta will be counted for each individual execution of the program, depending on the
        # ordering of the %transactionCategories hash in memory as the logic of this program is to 'last' once a matching transaction category 
        # has been found. 
        
        # Principal credit (old) is the capital value paid by the buyer of a loan that has been sold in the secondary market to a new lender
        # N.B. The sum of Principal credit and Interest credit should add up to the value of loans sold by the "Access Funds" process
        # (only confirmed for the old selling process before the new process for selling with a fee was introduced on 2 December 2019.
        # I have no data subsequent to the change as I have not sold any loans with the "Access Funds" tool since.)
        'Principal credit (old)' => {
            searchString => 'Loan_Part_ID [0-9]+:Principal ([0-9]+\.[0-9]{2}):.*,\g{1},\Z',
            column => 2,
            index => 10,
            visible => 1,
            derivedGroup => 0,
        },
        # Interest credit (old) is the partial month's interest paid by the buyer of a loan on the secondary market to the account holder.
        'Interest credit (old)' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Interest ([0-9]+\.[0-9]{2}):.*,\g{1},\Z',
            column => 2,
            index => 11,
            visible => 1,
            derivedGroup => 1,
        },
        # Principal debit (old) is the capital value paid to the orignal lender of a loan that has been purchased the secondary market.
        'Principal debit (old)' => {
            searchString => 'Loan_Part_ID [0-9]+:Principal ([0-9]+\.[0-9]{2}):.*,[0-9]+\.[0-9]{2},\g{1}\Z',
            column => 3,
            index => 12,
            visible => 1,
            derivedGroup => 0,
        },
        # Interest debit (old) is the partial month's interest paid to the orignal lender of a loan that has been purchased the secondary market.
        'Interest debit (old)' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Interest ([0-9]+\.[0-9]{2}):.*,[0-9]+\.[0-9]{2},\g{1}\Z',
            column => 3,
            index => 13,
            visible => 1,
            derivedGroup => 1,
        },
        # A historical feature of Funding Circle related to promotions. No longer used, replaced with the transfer fee.
        # NB: the regexp assumes it will always be a debit
        'Historical delta (old)' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Delta ([0-9]+\.[0-9]{2}):.*,[0-9]+\.[0-9]{2},\g{1}\Z',
            column => 3,
            index => 14,
            visible => 0,
            derivedGroup => 0,
        },
        # A historical feature of Funding Circle related to promotions. No longer used, replaced with the transfer fee.
        # NB: the regexp assumes it will always be a debit
        'Historical fees (old)' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Fee ([0-9]+\.[0-9]{2}),[0-9]+\.[0-9]{2},\g{1}\Z',
            column => 3,
            index => 15,
            visible => 0,
            derivedGroup => 0,
        },
        # Principal credit (new) is the capital value paid to the orignal lender of a loan that has been purchased the secondary market.
        'Principal credit (new)' => {
            searchString => 'Loan_Part_ID [0-9]+:Principal \x{00A3}([0-9]+\.[0-9]{2}):.*,\g{1},\Z',
            column => 2,
            index => 16,
            visible => 1,
            derivedGroup => 0,
        },
        # Interest credit (new) is the partial month's interest paid to the orignal lender of a loan that has been purchased the secondary market.
        # Value in the transaction description should be a positive number
        'Interest credit (new)' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Interest \x{00A3}-([0-9]+\.[0-9]{2}):.*,\g{1},[0-9]+\.[0-9]{2}\Z',
            column => 2,
            index => 17,
            visible => 1,
            derivedGroup => 1,
        },
        # Transfer fee debit is the is the 1.25% fee paid by the account holder to the purchaser of a loan sold on the secondary market.
        'Transfer fee debit' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Transfer_Payment \x{00A3}([0-9]+\.[0-9]{2}):.*,[0-9]+\.[0-9]{2},\g{1}\Z',   # TODO: Untested
            column => 3,
            index => 18,
            visible => 1,
            derivedGroup => 2,
        },
        # Principal debit (new) is the capital value paid to the orignal lender of a loan that has been purchased the secondary market.
        # TODO: Combine Principal debit (old) with Principal debit (new). Only difference in regexp will be optional '£' (\x{00A3}) in the transaction description
        'Principal debit (new)' => {
            searchString => 'Loan_Part_ID [0-9]+:Principal \x{00A3}([0-9]+\.[0-9]{2}):.*,[0-9]+\.[0-9]{2},\g{1}\Z',
            column => 3,
            index => 19,
            visible => 1,
            derivedGroup => 0,
        },
        # Interest debit (new) is the partial month's interest paid to the orignal lender of a loan that has been purchased the secondary market.
        # Value in the transaction description should be a positive number
        'Interest debit (new)' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Interest \x{00A3}([0-9]+\.[0-9]{2}):.*,[0-9]+\.[0-9]{2},\g{1}\Z',
            column => 3,
            index => 20,
            visible => 1,
            derivedGroup => 1,
        },
        # Transfer fee debit is the is the 1.25% fee paid by the seller of a loan sold on the secondary market to the account holder.
        # Value in the transaction description should be a negative number, but it should appear as a positive number in the credit column (after initial transaction line modificaiton)
        'Transfer fee credit' => {
            searchString => 'Loan_Part_ID [0-9]+.+:Transfer_Payment \x{00A3}-([0-9]+\.[0-9]{2}):.*,\g{1},[0-9]+\.[0-9]{2}\Z',
            column => 2,
            index => 21,
            visible => 1,
            derivedGroup => 2,
        },
        # Net interest is calculated in the same way as "INTEREST" on the Funding Circle website's Summary page:
        # Net interest = Interest repayment + Early interest repayment + Interest credit (old) + Interest credit (new) - Interest debit (old) - Interest debit (new)
        # N.B: This is solely a derived figure and a 'Net interest' transaction category will never appear in a statement
        'Net interest (derived)' => {
            searchString => 'XXX-Net-interest-XXX',     # As this is a derived category, its regexp should NEVER match a transaction category when parsing a statement!
            column => 2,
            index => 22,
            visible => 1,
            derivedGroup => -1,
        },
        # Net transfer fee is calculated in the same way as "NET TRANSFER FEE" on the Funding Circle website's Summary page:
        # N.B: This is solely a derived figure and a 'Net transfer fee' transaction category will never appear in a statement
        'Net transfer fee (derived)' => {
            searchString => 'XXX-Net-transfer-fee-XXX',     # As this is a derived category, its regexp should NEVER match a transaction category when parsing a statement!
            column => 2,
            index => 23,
            visible => 1,
            derivedGroup => -2,
        },
    );
    # print(Dumper(\%transactionCategories));

    # all the individual details of each transaction category to be recorded 
    my %transactionDetailHash = (
        searchString => '',                 # The search string of the transaction category, filled from %transactionCategories
        displayName => '',                  # The human readable name of the transaction category shown in the results, filled from %transactionCategories
        sumTotal => 0.00,                   # The sum of the transaction values of this category parsed from the statement
        numTransactions => 0,               # The number of transactions of this category parsed from the statement
        column => undef,                    # The column of the transaction category, filled from %transactionCategories
        index => undef,                     # The position in which to list the transaction category in the human readable results
        visible => undef,                   # Whether or not to show this category in the results tables
        derivedGroup => undef,              # The psotive numeric value of the associated derived category group this transaction category is associated with 
    );
    # print(Dumper(\%transactionDetailHash));

    # # create a single hash reference structure to hold all data from the statement file.
    my $emptyStatementData = {
        STATEMENTVOLUME => '',              # driveletter for a multiroot OS
        STATEMENTDIRECTORY => '',           # absolute path excluding filename
        STATEMENTFILENAME => '',            # filename only
        STATEMENTDATE => '',                # year and month only (YYYY-MM) parsed from statement filename
        STATEMENTDOWNLOADDATE => '',        # year, month and date (YYYY-MM-DD) parsed from statement filename
        STATEMENTTITLENAME => '',           # Formatted name for printable statement summary in 'Month Year Statement' format, or 'Totals'
        STATEMENTTABLENAME => '',           # Formatted name for csv statement table in 'YYYY-MM' format, or 'Totals'
        DATESTART => '',                    # earliest transaction date parsed from within the statement file
        DATEEND => '',                      # latest transaction date parsed from within the statement file
        TOTALTRANSACTIONLINES => 0,         # total number of transaction lines in the statement file
        TRANSACTIONDETAILSARRAY => undef,   # array of results for each transaction type parsed
    };
    # print(Dumper(\$emptyStatementData));

    # programatically create an array of hashes to hold all detils for all transaction categories
    my @transactionDetailsArray;
    while ( (my $key, my $value) = each(%transactionCategories)) {
        my %tempHash = %transactionDetailHash;
        $tempHash{displayName} = "$key";
        $tempHash{searchString} = %{$value}{searchString};
        $tempHash{column} = %{$value}{column};
        $tempHash{index} = %{$value}{index};
        $tempHash{visible} = %{$value}{visible};
        $tempHash{derivedGroup} = %{$value}{derivedGroup};
        push(@transactionDetailsArray, \%tempHash); 
    }
    # print(Dumper(\@transactionDetailsArray));

    # combine @transactionDetailsArray with emptyStatementData
    $emptyStatementData->{TRANSACTIONDETAILSARRAY} = \@transactionDetailsArray;
    # print(Dumper(\$emptyStatementData));

    # set initial values for DATESTART and DATEEND (or is it better to set to undef?)
    $emptyStatementData->{DATESTART} = Time::Piece->strptime("2050-01-01_00-00-00", "%Y-%m-%d_%H-%M-%S");
    $emptyStatementData->{DATEEND} = Time::Piece->strptime("2000-01-01", "%Y-%m-%d");

    # return a reference to the created data structure
    return $emptyStatementData;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# subroutine to parse a statement file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Arguments:
# $_[0] = path of statement file to be parsed
# Return Value:
# The data structure containing details of the parsed statement file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub parseFile {
    my $statementData = createStatementDataStructure();

    # parse the file's path into $statementData
    my @fileSpecArray = File::Spec->splitpath(File::Spec->rel2abs($_[0]));
    $statementData->{STATEMENTVOLUME} = $fileSpecArray[0];
    $statementData->{STATEMENTDIRECTORY} = $fileSpecArray[1];
    $statementData->{STATEMENTFILENAME} = $fileSpecArray[2];
    # print(Dumper(@fileSpecArray));

    # parse the filename only to get information on the period the statement covers and the date on which it was downloaded.
    # filename is of the format (ST = statement, DL = download)
    # statement_STYEAR-STMONTH_DLYEAR-DLMONTH-DLDAY_DLHOUR-DLMINUTE-DLSECOND.csv 
    my @filenameArray = split('_', $statementData->{STATEMENTFILENAME});
    foreach(@filenameArray) {
        if(/\.csv$/) {
            s/\.csv//;
        }
    }
    # print(Dumper(@filenameArray));

    # Reference for unix strptime/strftime conversion specifications: https://www.unix.com/man-page/FreeBSD/3/strftime/
    $statementData->{STATEMENTDATE} = Time::Piece->strptime($filenameArray[1], "%Y-%m");
    $statementData->{STATEMENTDOWNLOADDATE} = Time::Piece->strptime("$filenameArray[2]_$filenameArray[3]", "%Y-%m-%d_%H-%M-%S");
    # print(Dumper(\$statementData));

    # create formatted statement titles for each of the output formats
    $statementData->{STATEMENTTITLENAME} = $statementData->{STATEMENTDATE}->strftime("%B %Y Statement");
    $statementData->{STATEMENTTABLENAME} = $statementData->{STATEMENTDATE}->strftime("%Y-%m");

    # open the statement file for reading
    my $fh;
	open($fh, '<:encoding(UTF-8)', File::Spec->catpath(
        $statementData->{STATEMENTVOLUME},
        $statementData->{STATEMENTDIRECTORY},
        $statementData->{STATEMENTFILENAME}));
    # print("File to be parsed is $statementData->{STATEMENTFILENAME}\n");

    # parse the file, line by line
    while(my $line = <$fh>) {
        chomp $line;
        # ignore the line with the text for the column titles.
        if ($line =~ /^Date/) {
            # do nothing
        }

        # match any line starting with a date code of the format YYYY-MM-DD 
        elsif ($line =~ /^20[0-9]{2}-[0-1][0-9]-[0-3][0-9],/) {
            $statementData->{TOTALTRANSACTIONLINES}++;
            # prior to itentifying which category a each transaction belongs to, carry out some line reformatting to get rid of the following:
            # most of the following modifications apply specifically to the last-day-of-the-month entries containing the string "Loan Part ID ..."
            if($line =~ '"') {
                # print("         line: $line\n");
                # rewrite 'Loan Part ID' with underscores to aid splitting the transaction description on spaces if necessary later
                $line =~ s/Loan Part ID/Loan_Part_ID/g;
                # remove problematic commas within doublequoted sections of the transaction description which will otherwise interfere with spliting upon comma-delimited data columns later. 
                # use split to split upon the doublequotes, 
                # replace with colons the extraneous commas from [1] which should only ever be present in the troublesome transaction category description,
                # also removing unnecessary spaces at the same time
                # join the modified array elements together again.
                my @tempLineArray = split('"', $line);
                $tempLineArray[1] =~ s/\s*[,:]\s*/:/g;
                $line = join('', @tempLineArray);
                @tempLineArray = undef;
                # insert a value of 0.00 between two adjacent commas to prevent any inadvertent "use of uninitialized value in addition..." errors
                $line =~ s/,,/,0\.00,/g;
                # deal with the new method of purchasing and selling loans on the secondary market from 2 December 2019 which introduces derived
                # values in the credit or debit column calculated from multiple orignal values held within the transaction description field
                # These transactions are the only ones which contain a '£' symbol, a.k.a '\x{00A3}' in unicode
                # Each purchase is covered by two lines, one for ONLY the loan capital, the other containing BOTH Transfer Payment and Interest figures
                # TODO: Each loan sale is covered by two lines - OR is it three lines like with the old loan sales?
                if($line =~ /\x{00A3}/) {
                    # need to work out if the transaction is a loan sale or loan purchase based on whether the value of 'Transfer Payment'
                    # in the transaction description is positive or negative
                    # NB: Working half-blind as I only have transactions for loan purchases, NOT loan sales for this period for reference
                    # 
                    # If Transfer Payment is negative, then it is a loan purchase and two things must change:
                    # Transfer Payment must be copied to the credit column with its negative sign removed, and
                    # Interest must be copied to the debit colum.
                    # Currently AFAIK a net of these two figures will be displayed in the credit column, and nothing in the debit column
                    #
                    # Conversely, if the Transfer Payment is positive (speculation based on the above ) then it is a loan sale and two things must change:
                    # Transfer Payment must be copied to the debit column, and
                    # Interest must be copied to the credit column with its (SPECULATIVE) negative sign removed.
                    # Currently AFAIK a net of these two figures will be displayed in the debit column, and nothing in the credit column (NB: Speculation - I have no transactions to check against)
                    #
                    # Also note: This type of transaction also prevents the most efficient use of 'last' in the transaction category matching and summing code
                    # below as some lines now need to match against TWO transaction categories in order to record all necessary information.
                    # Distinguish between loan sales and loan purchases based on the sign of the Transfer Payment value

                    if($line !~ /Loan_Part_ID [0-9]+:Principal \x{00A3}([0-9]+\.[0-9]{2}):.*,.*\g{1}/) {
                        # Split line on commas, transaction description field on colons
                        @tempLineArray = split(',', $line);
                        $tempLineArray[1] =~ s/Transfer Payment/Transfer_Payment/;
                        # print(Dumper(@tempLineArray));
                        my @transactionDescriptionArray = split(':', $tempLineArray[1]);
                        # print(Dumper(@transactionDescriptionArray));
                        # Interest is at array index 2, Transfer Payment is at array index 3
                        (undef, my $interest) = split(' ', $transactionDescriptionArray[2]);
                        (undef, my $transferPayment) = split(' ', $transactionDescriptionArray[3]);
                        $transferPayment =~ s/\x{00A3}//g;
                        $interest =~ s/\x{00A3}//g;

                        # Distinguish between loan purchase and loan sale using a the sign of the Transfer Payment value
                        if($transferPayment =~ /-/) {    # loan purchase
                            $transferPayment =~ s/-//g;
                            my $net = $transferPayment - $interest;
                            # print("Interest value is $interest, Transfer Payment value is $transferPayment, net result is " . $net. "\n");
                            # now insert correct Interest and Transfer Payment values back into the lineArray before joining it all together again 
                            $tempLineArray[2] = $transferPayment;
                            $tempLineArray[3] = $interest;
                        }
                        else {  # loan sale, TODO: THIS IS SPECULATION, needs an example of an actual loan sale to confirm the logic here
                            $interest =~ s/-//g;    
                            my $net = $interest - $transferPayment;
                            # print("Interest value is $interest, Transfer Payment value is $transferPayment, net result is " . $net. "\n");
                            # now insert correct Interest and Transfer Payment values back into the lineArray before joining it all together again 
                            $tempLineArray[2] = $interest;
                            $tempLineArray[3] = $transferPayment;
                        }
                        # Put Humpty Dumpty back together again
                        # print(Dumper(@tempLineArray));
                        $tempLineArray[1] = join(':', @transactionDescriptionArray);
                        $line = join(',', @tempLineArray);
                    }
                }
                # values within the "Loan Part ID ..." transaction description are only displayed to 1DP in the credit/debit columns if the penny value is zero with prevents backreference matching
                # make sure all credit/debit values are displayed to 2DP 
                $line =~ s/(?<alpha>\.[0-9]),/$+{alpha}0,/g;
                $line =~ s/(?<alpha>\.[0-9])\Z/$+{alpha}0/g;
                # print("Modified line: $line\n");
            }

            # split the line according to the the comma delimiter
            my @splitLine = split(',', $line);
            my $matchFound = 0;
            
            # iterate through each array element in $statementData->{TRANSACTIONDETAILSARRAY}
            foreach( @{$statementData->{TRANSACTIONDETAILSARRAY}} ) {
                
                # test each line for a matching transaction category string and sum its value to $statementData match against $line instead of just $splitLine
                # as backreferences referencing the credit and debit columns are needed to properly match "Loan Part ID..." transaction categories
                if ($line =~ /$_->{searchString}/) {
                    $matchFound = 1;
                    # print("Matched the transaction category $->{searchString} for line $line\n");
                    # print("Transaction value for this $_->{searchString} is $splitLine[$_->{column}]\n");
                    $_->{sumTotal} += $splitLine[$_->{column}];
                    $_->{numTransactions}++;

                    # populate DATESTART and DATEEND fields in $statementData
                    my $newDate = Time::Piece->strptime("$splitLine[0]", "%Y-%m-%d");
                    if($newDate < $statementData->{DATESTART}) {
                        # print("DATESTART updated from $statementData->{DATESTART} to $newDate\n");
                        $statementData->{DATESTART} = $newDate;
                    }
                    if($newDate > $statementData->{DATEEND}) {
                        # print("DATEEND updated from $statementData->{DATEEND} to $newDate\n");
                        $statementData->{DATEEND} = $newDate;
                    }
                    # match found, so save time by not trying to carry on matching against any the remaining transaction categories
                    # UNLESS it is from one of the new post 2 December 2019 seondary market loan sales or purchases, which may need to be matched twice per line!
                    if($_->{index} < 15) {  # TODO: keep checking this {index} value is correct
                        last;
                    }
                }
            }
            # handle any unexpected lines
            if($matchFound == 0) {
                print("ERROR: Parsed a line containing an unexpected transaction category in the file: $statementData->{STATEMENTFILENAME}\n");
                print("ERROR: The unexpected line is: $line\n");
                print("       Please report the the contents of the line to richardjrl+funding-circle-statement-parser\@posteo.net\n");
                print("       to have it included in future versions of the program.\n")
            }
        }
    }

    # Calculate the derived 'Net Interest' category
    # TODO: Update this calc for the new secondary market loan sale/purchase transactions

    my @netValue;
    my @netNumTransactions;
    foreach( @{$statementData->{TRANSACTIONDETAILSARRAY}} ) {
        if($_->{derivedGroup} > 0) {
            if($_->{column} == 2) { # credit transactions
                $netValue[$_->{derivedGroup}] += $_->{sumTotal};
            }
            elsif($_->{column} == 3) { # debit transactions
                $netValue[$_->{derivedGroup}] -= $_->{sumTotal};
            }
            $netNumTransactions[$_->{derivedGroup}] += $_->{numTransactions};
        }
    }
    foreach( @{$statementData->{TRANSACTIONDETAILSARRAY}} ) {
        if($_->{derivedGroup} < 0) {
            my $posInt = $_->{derivedGroup};
            $posInt =~ s/-//g;
            $_->{sumTotal} = $netValue[$posInt];
            $_->{numTransactions} = $netNumTransactions[$posInt];
        }
    }

    # Change all debit column transactions into negative numbers
    foreach( @{$statementData->{TRANSACTIONDETAILSARRAY}} ) {
        if($_->{column} == 3 && $_->{sumTotal} != "0.00") {
            $_->{sumTotal} = "-" . $_->{sumTotal};
        }
    }

    # close filehandle
    close $fh;

    # return a reference to the filled data structure
    return $statementData;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# subroutine to nicely format the title for each monthly statement's results table
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Arguments:
# $_[0] = String to be displayed within the title bars
# Return Value:
# None
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub prettyStatementTitle {
    my $fillChar = '~';
    my $lineLength = 80;
    # Top title bounding line
    print($fillChar x $lineLength . "\n");
    # Title line (plus 2 for a whitespace at each end)
    my $titleLength = length($_[0])+2;
    my $paddingLength = (($lineLength - $titleLength)/2);
    print($fillChar x $paddingLength);
    print(" $_[0] ");
    if($titleLength%2 != 0) {
        $paddingLength++;
    }
    print($fillChar x $paddingLength . "\n");
    # Bottom title bounding line
    print($fillChar x $lineLength . "\n");
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~ START OF THE PRGRAM ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if(@ARGV) {
    # variable to hold a sorted list of all valid filenames from the command line arguments.
    my @fileList; 

    while(my $currentArg = shift(@ARGV)) {
        # check if argument is a file or directory
        if(-f $currentArg) {
            push(@fileList, File::Spec->rel2abs($currentArg));
        }
        elsif(-d $currentArg) {
            my $directory = File::Spec->rel2abs($currentArg);
            # Get directory contents and add any csv files found to @fileList. N.B. Not intended recurse through a directory tree
            my $dh;
            opendir($dh, $directory);
            if($directory =~ /[^\/]$/) {
                # print("Adding the missing trailing slash to the end of the directory path\n");
                $directory .= '/';
            }
            while(my $filename = readdir($dh)) {
                # print("File found: $filename\n");
                # only add the file to @fileList if it crudely matches the naming convention of a Funding Circle transaction statement
                if(($filename =~ /\Astatement_20[0-9]{2}.*\.csv\Z/)) {
                    push(@fileList, $directory . $filename);
                    # print("File added to list: $fileList[-1]\n");
                }
            }
            # close directory handle
            closedir $dh;
        }
        elsif($currentArg =~ /\A--/) {
            if($currentArg =~ /\A--csv\Z/) {
                $claCsv = 1;
            }
            elsif($currentArg =~ /\A--summary\Z/) {
                $claSummary = 1;
            }
            elsif($currentArg =~ /\A--name=/) {
                (undef, $claName) = split('=', $currentArg);
                $claName =~ s/,/\|/g;
            }
            else {
                print("ERROR: Unrecognised command line argument \'$currentArg\'\n")
            }
        }
        else { # Not a file, not a directory, not an output modifier, run around with hair on fire.
            print("ERROR: Invalid command line argument. '$currentArg' is neither a file nor a directory nor an output format specifier\n"); 
        }
    }

    # check that an appropriate combination of command line arguments have been received or exit
    # check at least one superficially valid file has been found in the command line arguments
    if(@fileList == 0) {
        $claErrors++;
        print("ERROR: No statement files found in the command line arguments:\n");
        print("At least one command line argument of either/both:\n");
        print("  a) one or more csv files, or\n");
        print("  b) one or more folders containing csv files\n");
        print("is required.\n");
    }
    # # check at least one output format specifier has been chosen
    if(($claSummary == 0) && ($claCsv == 0)) {
        $claErrors++;
        print("An output format specifier of either:\n");
        print("  --summary : for a pretty summary of transactions\n");
        print("  --csv     : for a csv table of transactions\n");
        print(" is required as a command line argument, but none has been found, exiting....\n");
    }
    if($claErrors != 0) {
        exit 1;
    }

    # Sort the complete @fileList by date
    @fileList = sort(@fileList);

    # Finally ready to parse all statement files that have been found and added to the @fileList
    while(my $currentFile =shift(@fileList)) {
        my $tempResults = parseFile($currentFile);
        push(@statementResults, \$tempResults);
    }

    # Calculate grand totals for each transaction category by summing from all statements parsed
    if(@statementResults > 1) {
        my $totals = createStatementDataStructure();
        $totals->{STATEMENTTITLENAME} = "Totals";
        $totals->{STATEMENTTABLENAME} = "Totals ";
        foreach(@statementResults) {
            my $result =${$_};

            # Make sure DATESTART and DATEEND cover the entire date range of all statements
            if($result->{DATESTART} < $totals->{DATESTART}) {
                $totals->{DATESTART} = Time::Piece->strptime($result->{DATESTART}->strftime("%Y-%m-%d_%H-%M-%S"), "%Y-%m-%d_%H-%M-%S");
            }
            if($result->{DATEEND} > $totals->{DATEEND}) {
                $totals->{DATEEND} = Time::Piece->strptime($result->{DATEEND}->strftime("%Y-%m-%d_%H-%M-%S"), "%Y-%m-%d_%H-%M-%S");
            }
            # Ignore the filename section; fill with undef?

            # Sum each transaction category sumTotal and numTransactions, this is more awkward than is should be...
            foreach my $res ( @{$result->{TRANSACTIONDETAILSARRAY}} ) {
                foreach my $tot (@{$totals->{TRANSACTIONDETAILSARRAY}}) {
                    my $resDisplayName = $res->{displayName};
                    my $totDisplayName = $tot->{displayName};
                    # can't have regexp special characters in the displayName comparison strings
                    $resDisplayName =~ s/[\(\)]//g;
                    $totDisplayName =~ s/[\(\)]//g;
                    if($resDisplayName =~ m/$totDisplayName/) {
                        $tot->{sumTotal} += $res->{sumTotal};
                        $tot->{numTransactions} += $res->{numTransactions};
                    }
                }
            }
        }
    # Add totals to the end of the @statementResults array
    push(@statementResults, \$totals);
    }

    # Print all collected results to check for completeness before parsing them again into human readable results
    # print(Dumper(@statementResults));

    # Print human readable results if --claSummary command line argument has been specified
    if($claSummary == 1) {
        foreach(@statementResults) {
            my $result =${$_};

            # Print pretty human readable title to visually deliniate each month's statement
            # my $statementTitle = $result->{DATESTART}->strftime("%B %Y") . " Statement";
            # if($result->{STATEMENTTITLENAME} !~ "Totals") {
                prettyStatementTitle($result->{STATEMENTTITLENAME});
            # }
            # else {
                # prettyStatementTitle("Totals");
            # }

            # Print statement date range, only including the year only if it differs in DATESTART AND DATEEND (useful for the totals table)
            if($result->{DATESTART}->year() =~ $result->{DATEEND}->year() ) {
                print("Summary of all transaction types from " . $result->{DATESTART}->strftime("%A %d %B") . " to " . $result->{DATEEND}->strftime("%A %d %B") . "\n");
                print("\n");
            }
            else {
                print("Totals of all transaction types from " . $result->{DATESTART}->strftime("%d %B %Y") . " to " . $result->{DATEEND}->strftime("%d %B %Y") . "\n");
                print("\n");
            }
            
            if($result->{STATEMENTTITLENAME} !~ "Totals") {
                # warn if statement does not cover from the start of the month (should only normally be triggered on month of account opening)
                my $firstSecondOfTheMonth = Time::Piece->strptime($result->{STATEMENTDATE}->strftime("%Y-") .
                                                            $result->{STATEMENTDATE}->strftime("%m-")  . "01_00-00-00", "%Y-%m-%d_%H-%M-%S" );
                if($result->{DATESTART} > $firstSecondOfTheMonth) {
                    print("WARNING: Statement may not contain all transactions for the whole calendar month\n");
                    print("         Statement contains transactions from " . $result->{DATESTART}->strftime("%d %B %Y") . " to " . $result->{DATEEND}->strftime("%d %B %Y") . "\n");
                    print("\n");
                }
                # warn if statement does not cover the to the end of the month (usually if the latest statement has been downloaded before the end of the month)
                my $lastSecondOfTheMonth = Time::Piece->strptime($result->{STATEMENTDATE}->strftime("%Y-") .
                                                            $result->{STATEMENTDATE}->strftime("%m-")  . 
                                                            $result->{STATEMENTDATE}->month_last_day . "_23-59-59", "%Y-%m-%d_%H-%M-%S" );
                if($result->{STATEMENTDOWNLOADDATE} < $lastSecondOfTheMonth) {
                    print("WARNING: Statement may not contain all transactions for the whole calendar month\n");
                    print("         Statement was downloaded at " . $result->{STATEMENTDOWNLOADDATE}->strftime("%T") . " on " . $result->{STATEMENTDOWNLOADDATE}->strftime("%d %B %Y") . " and\n");
                    print("         contains no recorded transactions after " . $result->{DATEEND}->strftime("%d %B %Y") . ".\n");
                    print("\n");
                }
            }
            
            # Preparatory work before printing each transaction category
            # Variables are required to store various maximum string lengths the calculation of which will later aid in formatting and aligning the results
            my $longestCategoryLength = 0;  # longest transaction category string length
            my $longestSumLengh = 0;        # longest sum string length; pounds only, does not need to include pence part which will always be 2.
            my $longestNumTransactionsLength = 1;  # longest number of transactions string length. Even 0 transactions has a length of 1
            foreach( @{$result->{TRANSACTIONDETAILSARRAY}} ) {
                if($_->{visible} == 1) {
                    # calculate longest category string length
                    my $tempStringLength = length($_->{displayName});
                    if($tempStringLength > $longestCategoryLength) {
                        $longestCategoryLength = $tempStringLength;
                    }
                    # calculate longest sum string length (pounds part only)
                    if($_->{numTransactions} != 0) {
                        my $poundsPartLength = 0;
                        if($_->{sumTotal} =~ /\./) {
                            my @sumArray = split('\.', "$_->{sumTotal}");
                            $poundsPartLength = length("$sumArray[0]");
                        }
                        else {
                            $poundsPartLength = length("$_->{sumTotal}");
                        }
                        if($poundsPartLength > $longestSumLengh) {
                            $longestSumLengh = $poundsPartLength;
                        }
                    }
                    # calculate longest number of transactions string length
                    $tempStringLength = length($_->{numTransactions});
                    if($tempStringLength > $longestNumTransactionsLength) {
                        $longestNumTransactionsLength = $tempStringLength;
                    }
                }
            }

            # Print each transaction category
            my @prettyResults;
            foreach( @{$result->{TRANSACTIONDETAILSARRAY}} ) {
                if($_->{visible} == 1) {
                    # use sprintf to populate an array of formatted strings for output once the order of each transaction category has been read from its {index}.
                    my $resultArray = $_;
                    my $prettyString = "\t\%-" . $longestCategoryLength . "s  £%" . ($longestSumLengh+4) . ".2f from \%" . $longestNumTransactionsLength . "d transactions";
                    my $prettyStringZeroTransactions = "\t\%-" . $longestCategoryLength . "s  £%" . ($longestSumLengh+4) . ".2f";
                    my $sparsePrettyResults = 0;
                    if($sparsePrettyResults == 1) {
                        if($resultArray->{visible} == 1) {
                            if($resultArray->{numTransactions} != 0) {
                                $prettyResults[$resultArray->{index}] = sprintf("$prettyString", $resultArray->{displayName}, $resultArray->{sumTotal}, $resultArray->{numTransactions});
                            }
                            else {
                                $prettyResults[$resultArray->{index}] = sprintf("$prettyStringZeroTransactions", $resultArray->{displayName}, $resultArray->{sumTotal});
                            }
                        }
                    }
                    else {
                        if($resultArray->{visible} == 1) {
                            $prettyResults[$resultArray->{index}] = sprintf("$prettyString", $resultArray->{displayName}, $resultArray->{sumTotal}, $resultArray->{numTransactions});
                        }
                    }
                }
            }
            # print(Dumper(@prettyResults));

            # print the prettyResults array contents
            foreach(@prettyResults) {
                if(defined($_)) {
                    print($_ . "\n");
                }
            }
            # Final newline before the next statement is printed
            print("\n" x 2);
        }
    }
    
    # Print a csv table of each month's statement data if the command line argument --csv has been specified
    if($claCsv == 1) {
        # create a list of colunm headings sorted according to their index number (see %transactionCategories->{index} for reference)
        my @columnHeadingTextArray = ("Date");
        my @columnsToRemove;
        foreach(@{${$statementResults[0]}->{TRANSACTIONDETAILSARRAY}}) {
            $columnHeadingTextArray[$_->{index}+1] = "$_->{displayName}";
            if($_->{visible} == 0) {
                push(@columnsToRemove, $_->{index});
            }
        }
        @columnsToRemove = sort{$a<=>$b}(@columnsToRemove);
        # print(Dumper(@columnsToRemove));
        # Remove transaction categories that are not selected to be visible
        my $removedColumnsCounter = 0;
        foreach(@columnsToRemove) {
            splice(@columnHeadingTextArray, $_+1-$removedColumnsCounter, 1);
            $removedColumnsCounter++;
        }
        # print(Dumper(@columnHeadingTextArray));
        # store the length of each heading text
        my @columnHeadingLengthArray;
        for(0...@columnHeadingTextArray-1) {
            $columnHeadingLengthArray[$_] = length($columnHeadingTextArray[$_]) + 1;
        }

        # create a 2D table of values for each transaction cateory and each statement
        my @resultsTable;
        foreach(@statementResults) {
            my $result =${$_};
            my @tableRow;
            # add the statement date first
            push(@tableRow, $result->{STATEMENTTABLENAME});
            # now add all transaction categories
            foreach(@{$result->{TRANSACTIONDETAILSARRAY}}) {
                $tableRow[$_->{index}+1] = sprintf("%.2f", "$_->{sumTotal}");
            }
            # Remove transaction categories that are not selected to be visible
            $removedColumnsCounter = 0;
            foreach(@columnsToRemove) {
                splice(@tableRow, $_+1-$removedColumnsCounter, 1);
                $removedColumnsCounter++;
            }
            # print(Dumper(\@tableRow));
            push(@resultsTable, \@tableRow);
        }
        # print(Dumper(\@resultsTable));

        # check that no column heading width is narrower than the widest data value in that column
        foreach(@resultsTable) {
            my @resultsText = @{$_};
            # print(@resultsText . "\n");
            for(0...@resultsText-1) {
                if(length($resultsText[$_]) >= $columnHeadingLengthArray[$_]) {
                    # print("OLD: resultsText is " . $resultsText[$_] . ", length of resultsText is " . length($resultsText[$_]) . ", headingText is " . $columnHeadingTextArray[$_] . ", length of headingText is " . $columnHeadingLengthArray[$_] . "\n");
                    $columnHeadingLengthArray[$_] = length($resultsText[$_])+1;
                    # print("NEW: resultsText is " . $resultsText[$_] . ", length of resultsText is " . length($resultsText[$_]) . ", headingText is " . $columnHeadingTextArray[$_] . ", length of headingText is " . $columnHeadingLengthArray[$_] . "\n");
                }
            }
        }
        # print all the column headings
        my $columnHeadingLine = '';
        for(0...@columnHeadingTextArray-1) {
            $columnHeadingLine .= sprintf('%' . $columnHeadingLengthArray[$_] . 's,', $columnHeadingTextArray[$_]);
        }
        $columnHeadingLine =~ s/,\Z/\n/;
        print($columnHeadingLine);
        
        # print all the column data
        foreach(@resultsTable) {
            my @resultsLine = @{$_};
            my $tableLine;
            for(0...@resultsLine-1) {
                $tableLine .= sprintf('%' . $columnHeadingLengthArray[$_] . 's,', $resultsLine[$_]);
            }
            $tableLine =~ s/,\Z/\n/;
            print($tableLine);
        }
        print("\n");
    }
}
# Error/help message to display if program run without command line arguments
else {
    print("At least one command line argument of either/both:\n");
    print("  a) one or more csv files, or\n");
    print("  b) one or more folders containing csv files\n");
    print("is required.\n");
    print("Also an output format specifier of either:\n");
    print("  --summary : for a pretty summary of transactions\n");
    print("  --csv     : for a csv table of transactions\n");
    print(" is required, but none has been found, exiting....\n");
}