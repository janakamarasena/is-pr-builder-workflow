#!/bin/bash +x
echo ""
echo "=========================================================="
echo "    PR_LINK: $PR_LINK"

USER=$(echo $PR_LINK | awk -F'/' '{print $4}')
REPO=$(echo $PR_LINK | awk -F'/' '{print $5}')
PULL_NUMBER=$(echo $PR_LINK | awk -F'/' '{print $7}')

echo "    USER: $USER"
echo "    REPO: $REPO"
echo "    PULL_NUMBER: $PULL_NUMBER"
echo "=========================================================="


echo "Cloning product-is"
echo "=========================================================="
git clone https://github.com/wso2/product-is

if [ "$REPO" != "product-is" ]; then
  echo ""
  echo "=========================================================="
  echo "$REPO is not supported by this builder Exiting..."
  echo "=========================================================="
  echo ""
  echo "::error::$REPO is not supported by this builder"
  exit 1
fi


echo ""
echo "PR is for the product-is itself. Start building with test..."
echo "=========================================================="
cd product-is

echo ""
echo "Applying PR $PULL_NUMBER as a diff..."
echo "=========================================================="
wget -q --output-document=diff.diff $PR_LINK.diff
cat diff.diff
echo "=========================================================="
git apply diff.diff || { echo 'Applying diff failed. Exiting...' ; exit 1; }

echo "<h3>Last 3 changes:</h3><ul>" >> $RTPP_FILE
COMMIT1=$(git log --oneline -1)
COMMIT2=$(git log --oneline -2|tail -1)
COMMIT3=$(git log --oneline -3|tail -1)
echo "<li>$COMMIT1</li>" >> $RTPP_FILE
echo "<li>$COMMIT2</li>" >> $RTPP_FILE
echo "<li>$COMMIT3</li></ul>" >> $RTPP_FILE

cat pom.xml
mvn clean install --batch-mode | tee mvn-build.log

PR_BUILD_STATUS=$(cat mvn-build.log | grep "\[INFO\] BUILD" | grep -oE '[^ ]+$')
PR_TEST_RESULT=$(sed -n -e '/\[INFO\] Results:/,/\[INFO\] Tests run:/ p' mvn-build.log)

PR_BUILD_FINAL_RESULT=$(
  echo "==========================================================="
  echo "product-is BUILD $PR_BUILD_STATUS"
  echo "=========================================================="
  echo ""
  echo "$PR_TEST_RESULT"
)

PR_BUILD_RESULT_LOG_TEMP=$(echo "$PR_BUILD_FINAL_RESULT" | sed 's/$/%0A/')
PR_BUILD_RESULT_LOG=$(echo $PR_BUILD_RESULT_LOG_TEMP)
echo "::warning::$PR_BUILD_RESULT_LOG"

if [ "$PR_BUILD_STATUS" != "SUCCESS" ]; then
  echo "PR BUILD not successfull. Aborting."
  echo "::error::PR BUILD not successfull. Check artifacts for logs."
  exit 1
fi

echo ""
echo "=========================================================="
echo "Build completed"
echo "=========================================================="
echo ""
