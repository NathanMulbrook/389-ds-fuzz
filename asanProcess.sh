#!/usr/bin/env bash
mkdir -p logs/oldasan
cp asanfiltered.log logs/oldasan/
echo -e "\n\n############ ASAN ##############\n\n" > asanfiltered.log
cat logs/asan* | \

#remove ubsan | \
grep -v "SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior " | \
grep -v ": runtime error: " | \
grep -v ": note: pointer points here" | \
grep -v "note: nonnull attribute specified here" | \
grep -E -v '(.{1,2}[0-9a-f]{2,2}){32}' | \
grep -E -v '\s{1,100}\^\s' | \

sed -E ':a;N;$!ba;s/\n/####/g'  | \
sed -E 's/(0x)[0]{12}/null/g' | \
sed -E 's/(==)[0-9]{3,}(==)/==????==/g' | \
sed -E 's/(0x)[0-9a-fA-F]{3,}\:(.[0-9a-f]{2,2}){16}\]*/???? ?????????????????????????????????/g' | \
sed -E 's/(0x)[0-9a-fA-F]{3,}/????/g' | \
sed -E 's/([Tt]hread T)[0-9]{0,3}/thread T???/g' | \
sed -E 's/(src_)[0-9]{1,2}/src_?/g' | \
sed -E 's/(run_)[0-9]{1,2}/run_?/g' | \
sed -E 's/(\?\?\?\?\sT[0-9]{1,2})/???? T??/g' | \
sed -E 's/\(BuildId: [0-9a-f]{15,40}\)/\(BuildId\: ?????????????\)/g' | \
#sed -E 's/\?{4} \?{33}\] | \



sed  's/####=================================================================/\n=================================================================/g' | \
grep -v -e 'attempting\sfree\son\saddress\swhich\swas\snot\smalloc.*ch_malloc\.c\:266\:' | \


sort | \
uniq | \
#sed 's/=================================================================####/=================================================================\n/g' | \
sed  's/####/\n/g' >> asanfiltered.log

echo -e "\n\n############ UBSan ##############\n\n" >> asanfiltered.log
cat logs/asan* | \
grep ": runtime error: " | \

sed -E 's/(0x)[0]{12}/null/g' | \
sed -E 's/(0x)[0-9a-fA-F]{3,}/????/g' | \
sed -E 's/(src_)[0-9]{1,2}/src_?/g' | \
sed -E 's/(run_)[0-9]{1,2}/run_??/g' | \
sort | \
uniq >> asanfiltered.log





sort asanfiltered.log | grep "ERROR" | grep "AddressSanitizer" | sort | uniq -c
printf "UBSan : "
sort asanfiltered.log | grep ": runtime error: " | wc -l


