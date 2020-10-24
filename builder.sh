#!/bin/bash +x
wget https://raw.githubusercontent.com/mevan-karu/pom_version_property_finder/master/src/version_property_finder.py
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

echo ""
echo "PR is for the dependency repository $REPO."
echo ""
echo "Cloning $USER/$REPO"
echo "=========================================================="
git clone https://github.com/$USER/$REPO

echo ""
echo "Determining dependency version property key..."
echo "=========================================================="
VERSION_PROPERTY=$(python version_property_finder.py $REPO product-is 2>&1)

VERSION_PROPERTY_KEY=""
if [ "$VERSION_PROPERTY" != "invalid" ]; then
  echo "Version property key for the $REPO is $VERSION_PROPERTY"
  VERSION_PROPERTY_KEY=$VERSION_PROPERTY
else
  echo ""
  echo "=========================================================="
  echo "$REPO is not yet supported! Exiting..."
  echo "=========================================================="
  echo ""
  echo "::error::PR builder not supprted"
  exit 1
fi

echo ""
echo "Property key found: $VERSION_PROPERTY_KEY"
cd $REPO

DEPENDENCY_VERSION=$(mvn -q -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive exec:exec)
echo "Dependency Version: $DEPENDENCY_VERSION"
echo ""
echo "Applying PR $PULL_NUMBER as a diff..."
echo "=========================================================="
wget -q --output-document=diff.diff $PR_LINK.diff
cat diff.diff
echo "=========================================================="
git apply diff.diff || {
  echo 'Applying diff failed. Exiting...'
  echo "::error::Applying diff failed."
  exit 1
}

echo ""
echo "Building dependency repo $REPO..."
echo "=========================================================="
mvn clean install --batch-mode | tee mvn-build.log

echo ""
echo "Dependency repo $REPO build complete."
echo "Built version: $DEPENDENCY_VERSION"
echo "=========================================================="
echo ""

REPO_BUILD_STATUS=$(cat mvn-build.log | grep "\[INFO\] BUILD" | grep -oE '[^ ]+$')
REPO_TEST_RESULT=$(sed -n -e '/Results :/,/Tests run:/ p' mvn-build.log)

REPO_FINAL_RESULT=$(
  echo "==========================================================="
  echo "$REPO BUILD $REPO_BUILD_STATUS"
  echo "=========================================================="
  echo ""
  echo "Built version: $DEPENDENCY_VERSION"
  echo ""
  echo "$REPO_TEST_RESULT"
)

REPO_BUILD_RESULT_LOG_TEMP=$(echo "$REPO_FINAL_RESULT" | sed 's/$/%0A/')
REPO_BUILD_RESULT_LOG=$(echo $REPO_BUILD_RESULT_LOG_TEMP)
echo "::warning::$REPO_BUILD_RESULT_LOG"

if [ "$REPO_BUILD_STATUS" != "SUCCESS" ]; then
  echo "$REPO BUILD not successfull. Aborting."
  echo "::error::$REPO BUILD not successfull. Check artifacts for logs."
  exit 1
fi


cd ../product-is

echo "Updating dependency version in product-is..."
echo "=========================================================="
echo ""

sed -i "s/<$VERSION_PROPERTY_KEY>.*<\/$VERSION_PROPERTY_KEY>/<$VERSION_PROPERTY_KEY>$DEPENDENCY_VERSION<\/$VERSION_PROPERTY_KEY>/" pom.xml
cat pom.xml
mvn clean install --batch-mode | tee mvn-build.log

PR_BUILD_STATUS=$(cat mvn-build.log | grep "\[INFO\] BUILD" | grep -oE '[^ ]+$')
PR_TEST_RESULT=$(sed -n -e '/Results :/,/Tests run:/ p' mvn-build.log)

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
