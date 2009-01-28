#!/bin/bash
#okay, this line borks foldernames with " " in them... whatever :p
FILES=`echo *`
TMPDIR=tmp-$RANDOM

mkdir $TMPDIR
echo $FILES;
for file in $FILES; do
	if [ -d $file ]; then
		cp -r "$file" $TMPDIR
		cd $TMPDIR
		mv "$file" "webless-praktomat_$file"
		find "webless-praktomat_$file" -name .svn -type d -exec rm -rf \{\} \; 2> /dev/null
		tar -czf "webless-praktomat_$file.tgz" "webless-praktomat_$file"
		mv "webless-praktomat_$file.tgz" ..
		cd ..
	fi
done
rm -rf $TMPDIR
