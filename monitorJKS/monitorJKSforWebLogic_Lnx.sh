#!/bin/bash
#Author: M.Fevzi Korkutata | Last day of 2017 (New year PARTY script)

#Change environment variables:
__scriptPath=/home/oracle/scripts/monitorJKS
__keytool="/u01/weblogic/jdk8/jdk1.8.0_112/bin/keytool"
__keystore="/u01/weblogic/Middleware12212/wlserver/server/lib/DemoTrust.jks"
__keystorepass="DemoTrustKeyStorePassPhrase"
__thresholdDay="7"
__mailTo="person1@company.comx person2@company.comx"

#Static Variables
__currentDate=$(date +%s)
__threshold=$(($__currentDate + ($__thresholdDay*24*60*60)))

#Flush output values
echo -n > $__scriptPath/certificateStatus.txt
echo -n > $__scriptPath/certificateExpireWarning.txt
echo -n > $__scriptPath/certificateSummary.txt

#Fetch certificate "until"  dates
for i in $($__keytool -list -v -keystore $__keystore -storepass $__keystorepass | grep 'Alias name:' | perl -ne 'if(/name: (.*?)\n/) { print "$1\n"; }')
do
	echo "$i valid until: "$($__keytool -list -v -keystore $__keystore -storepass $__keystorepass -alias "$i" | grep 'Valid from' | head -1 | perl -ne 'if(/until: (.*?)\n/) { print "$1\n"; }') >> $__scriptPath/certificateStatus.txt
done

#Calculate certificate remaining days
__lc=$(cat $__scriptPath/certificateStatus.txt | wc -l)
for (( c=1 ; c<=$__lc ; c++ ))
do
	__alias=$(awk "NR==$c" $__scriptPath/certificateStatus.txt | awk '{print $1}')
	__until=$(awk "NR==$c" $__scriptPath/certificateStatus.txt | perl -ne 'if(/until: (.*?)\n/) { print "$1\n"; }')
	#echo $__until

	__untilSeconds=`date -d "$__until" +%s`
	__remainingDays=$(( ($__untilSeconds -  $(date +%s)) / 60 / 60 / 24 ))

	if [ $__threshold -le $__untilSeconds ]; then
        	#printf "[OK]         ===> $__alias <===  Certificate '$__alias' expires in '$__until'! *** $__remainingDays day(s) remaining ***\n\n"
        	printf "[OK]         ===> $__alias <===  Certificate '$__alias' expires in '$__until'! *** $__remainingDays day(s) remaining ***\n\n" >> $__scriptPath/certificateSummary.txt
	elif [ $__remainingDays -le 0 ]; then
		#printf "[CRITICAL]   ===> $__alias <===  !!! Certificate '$__alias' has already expired !!!\n"
		printf "[CRITICAL]   ===> $__alias <===  !!! Certificate '$__alias' has already expired !!!\n" >> $__scriptPath/certificateSummary.txt

	else
		#printf "[WARNING]    ===> $__alias <===  Certificate '$__alias' expires in '$__until'! *** $__remainingDays day(s) remaining ***\n\n"
		printf "[WARNING]    ===> $__alias <===  Certificate '$__alias' expires in '$__until'! *** $__remainingDays day(s) remaining ***\n\n" >> $__scriptPath/certificateSummary.txt
		printf "[WARNING]    ===> $__alias <===  Certificate '$__alias' expires in '$__until'! *** $__remainingDays day(s) remaining ***\n\n" >> $__scriptPath/certificateExpireWarning.txt
	fi
done

#Decide on ALERT
__lcCEW=$(cat $__scriptPath/certificateExpireWarning.txt | wc -l)
if [ $__lcCEW -gt 0 ]; then
	(>&2 echo "!!! [WARNING] Check expired certificates !!!")
	(>&2 echo "$(cat $__scriptPath/certificateExpireWarning.txt)")
	#Comment out if you want to send as WARNING email.
	#cat $__scriptPath/certificateExpireWarning.txt $__scriptPath/certificateSummary.txt | mail -s "!!! [WARNING] Check expired certificates !!!" $__mailTo
	exit 1
else
	echo "Script executed successfully! Certificates are OK!"
	echo " "
	echo "##################################################"
	cat $__scriptPath/certificateSummary.txt
	exit 0
fi
