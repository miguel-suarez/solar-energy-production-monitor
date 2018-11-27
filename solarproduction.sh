#!/bin/bash
set -e
SITE_ID=$1
KEY_ID=$2
START_YEAR=$3
SKIP_FETCH=$4
CURRENT_YEAR=$(date +%Y)
PREVIOUS_MONTH_INDEX=$(($(date -v15d -v-1m +%m)-1))  # -2 one to go to previous month and one to match it with the entry on the array (first index = 0)
years=$(($CURRENT_YEAR - $START_YEAR + 1))
kws[$years]="null";
counter=0;

writeProductionFiles() {
  for ((year=$START_YEAR; year<=$CURRENT_YEAR; year++)); do
	curl -k "https://monitoringapi.solaredge.com/site/$SITE_ID/energy?timeUnit=MONTH&startDate=$year-01-01&endDate=$year-12-31&api_key=$KEY_ID" | jq -r '.energy.values[] | "\(.date) \(.value)"' > production_$year.txt
  done
}

readProductionFiles() {
  for ((year=$START_YEAR; year<=$CURRENT_YEAR; year++)); do
    kw=""

	while read pdate ptime pamount; do
		kw="$kw $pamount" 
	done <production_$year.txt

	kws[$counter]=$kw
	((counter++))
  done

  #echo ${kws[0]}
  #echo ${kws[1]}
}

calculateAveragePerMonth() {
	avg[11]=0

	for ((m=0; m<=11; m++)); do
		monthValues=0
		monthProduction=0
		for ((y=0; y<$years; y++)); do
			arr=(${kws[y]})
			if [ "${arr[m]}" != "null" ]; then
				if [ $(($y+1)) -eq $years ] && [ $m -eq $PREVIOUS_MONTH_INDEX ]; then 
					# We don't want to include this on the average
					PREVIOUS_MONTH_KW=${arr[m]} 
				else
					((monthValues++))
					((monthProduction+=${arr[m]}))	
				fi			
			fi
		done
		avg[$m]=$((monthProduction/monthValues))
	done
}

printResult() {
	prefix="On $(date -v15d -v-1m +'%B %Y') the solar energy produced was: $(($PREVIOUS_MONTH_KW/1000)) KW."
	sufix="on the previous $(($years-1)) year(s) in that month"

	if [ $PREVIOUS_MONTH_KW -gt ${avg[$PREVIOUS_MONTH_INDEX]} ]; then
		percentage=$(bc <<< "scale=2;(($PREVIOUS_MONTH_KW/${avg[$PREVIOUS_MONTH_INDEX]})-1)*100")
		echo $prefix "It's $percentage% higher than the average" $sufix":" $((${avg[$PREVIOUS_MONTH_INDEX]}/1000)) "KW."
	elif [ $PREVIOUS_MONTH_KW -lt ${avg[$PREVIOUS_MONTH_INDEX]} ]; then	
		percentage=$(bc <<< "scale=2;((${avg[$PREVIOUS_MONTH_INDEX]}/$PREVIOUS_MONTH_KW)-1)*100")
		echo $prefix "It's $percentage% lower than the average" $sufix":" $((${avg[$PREVIOUS_MONTH_INDEX]}/1000)) "KW."
	else
		echo $prefix "It's equal to the average" $sufix"."
	fi	
}


if [ -z "$SKIP_FETCH" ]; then
   writeProductionFiles
fi

readProductionFiles
calculateAveragePerMonth
printResult
