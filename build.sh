#!/bin/bash
if [ "x$JAVA_HOME14" == "x" ] ; then
    echo 'Must specify $JAVA_HOME14, pointing to JDK 14 home'
    exit 1;
fi;

if [ "x$JAVA_HOME8" == "x" ] ; then
    echo 'Must specify $JAVA_HOME8, pointing to JDK 8 home'
    exit 1;
fi;

echo "Preparing CompilerProperties:"

rm -rf build/tools
mkdir -p build/tools/classes
mkdir -p build/tools/properties

JAVA_HOME=$JAVA_HOME14 PATH=$JAVA_HOME/bin:$PATH javac -d build/tools/classes -source 14 -target 14 --limit-modules java.base,java.xml,jdk.zipfs --add-exports java.base/jdk.internal=ALL-UNNAMED `find openjdk/make/langtools/tools/propertiesparser -name "*.java" -type f` || exit 1
mkdir -p build/tools/classes/propertiesparser/resources
cp openjdk/make/langtools/tools/propertiesparser/resources/templates.properties build/tools/classes/propertiesparser/resources/templates.properties
JAVA_HOME=$JAVA_HOME14 PATH=$JAVA_HOME/bin:$PATH java -cp build/tools/classes propertiesparser.PropertiesParser -compile openjdk/src/jdk.compiler/share/classes/com/sun/tools/javac/resources/compiler.properties build/tools/properties || exit 1

SOURCEFILES=`find openjdk/src/java.compiler/share/classes openjdk/src/jdk.compiler/share/classes build/tools/properties -name "*.java" -type f -not -name "module-info.java" -not -path "openjdk/src/jdk.compiler/share/classes/com/sun/tools/javac/launcher/Main.java" -not -path "openjdk/src/jdk.compiler/share/classes/com/sun/tools/javac/main/JavacToolProvider.java"`

echo "Preparing ct.sym:"

rm -rf build/ct.sym-source
mkdir -p build/ct.sym-source

cp openjdk/make/data/symbols/* build/ct.sym-source

(cd build/ct.sym-source;
 $JAVA_HOME14/bin/java --add-exports jdk.jdeps/com.sun.tools.classfile=ALL-UNNAMED \
            --add-exports jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
            --add-exports jdk.compiler/com.sun.tools.javac.jvm=ALL-UNNAMED \
            --add-exports jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
            --add-modules jdk.jdeps \
            ../../openjdk/make/langtools/src/classes/build/tools/symbolgenerator/CreateSymbols.java build-description-incremental symbols include.list)

rm -rf build/ct.sym
mkdir -p build/ct.sym

$JAVA_HOME14/bin/java --add-exports jdk.jdeps/com.sun.tools.classfile=ALL-UNNAMED \
            --add-exports jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
            --add-exports jdk.compiler/com.sun.tools.javac.jvm=ALL-UNNAMED \
            --add-exports jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
            --add-modules jdk.jdeps \
            openjdk/make/langtools/src/classes/build/tools/symbolgenerator/CreateSymbols.java build-ctsym build/ct.sym-source/symbols build/ct.sym

for f in `find build/ct.sym -name "*.sig"`; do mv $f `dirname $f`/`basename $f .sig`.class; done

echo "Building frgaal, phase1:"
rm -rf build/phase1
mkdir -p build/phase1/classes

JAVA_HOME=$JAVA_HOME14 PATH=$JAVA_HOME/bin:$PATH javac -d build/phase1/classes -source 14 -target 14 --limit-modules java.base,java.xml,jdk.zipfs $SOURCEFILES || exit 1

mkdir -p build/phase1/classes/com/sun/tools/javac/resources
cp openjdk/src/jdk.compiler/share/classes/com/sun/tools/javac/resources/*.properties build/phase1/classes/com/sun/tools/javac/resources/

mkdir -p build/phase1/classes/META-INF
cp -r build/ct.sym build/phase1/classes/META-INF

echo "Building frgaal, phase2:"
rm -rf build/phase2
mkdir -p build/phase2/classes

#JAVA_HOME=$JAVA_HOME14 PATH=$JAVA_HOME/bin:$PATH java --limit-modules java.base,java.xml,jdk.zipfs -classpath build/phase1/classes org.frgaal.Main -source 14 -target 8 -bootclasspath $JAVA_HOME8/jre/lib/rt.jar -d build/phase2/classes $SOURCEFILES || exit 1
JAVA_HOME=$JAVA_HOME14 PATH=$JAVA_HOME/bin:$PATH java --limit-modules java.base,java.xml,jdk.zipfs -classpath build/phase1/classes org.frgaal.Main -source 14 -target 8 -d build/phase2/classes $SOURCEFILES || exit 1

mkdir -p build/phase2/classes/com/sun/tools/javac/resources
cp openjdk/src/jdk.compiler/share/classes/com/sun/tools/javac/resources/*.properties build/phase2/classes/com/sun/tools/javac/resources/

mkdir -p build/phase2/classes/META-INF/
cp -r build/ct.sym build/phase2/classes/META-INF/

echo "Building frgaal, phase3:"
rm -rf build/phase3
mkdir -p build/phase3/classes

#JAVA_HOME=$JAVA_HOME8 PATH=$JAVA_HOME/bin:$PATH java -classpath build/phase2/classes org.frgaal.Main -source 14 -target 8 -bootclasspath $JAVA_HOME8/jre/lib/rt.jar -d build/phase3/classes $SOURCEFILES || exit 1
JAVA_HOME=$JAVA_HOME8 PATH=$JAVA_HOME/bin:$PATH java -classpath build/phase2/classes org.frgaal.Main -source 14 -target 8 -d build/phase3/classes $SOURCEFILES || exit 1

mkdir -p build/phase3/classes/com/sun/tools/javac/resources
cp openjdk/src/jdk.compiler/share/classes/com/sun/tools/javac/resources/*.properties build/phase3/classes/com/sun/tools/javac/resources/

mkdir -p build/phase3/classes/META-INF/
cp -r build/ct.sym build/phase3/classes/META-INF/

rm -rf dist
mkdir dist

(cd build/phase3/classes; $JAVA_HOME14/bin/jar --create --main-class org.frgaal.Main -f ../../../dist/compiler-`cat ../../../VERSION`.jar `find . -type f`)

rm -rf build/sources
mkdir -p build/sources
cp -r openjdk/src/java.compiler/share/classes/* build/sources
cp -r openjdk/src/jdk.compiler/share/classes/* build/sources
cp -r build/tools/properties/* build/sources/com/sun/tools/javac/resources/

(cd build/sources; $JAVA_HOME14/bin/jar --create -f ../../dist/compiler-`cat ../../VERSION`-sources.jar `find . -type f`)

mkdir -p build/javadoc
echo "No javadoc" >build/javadoc/README

(cd build/javadoc; $JAVA_HOME14/bin/jar --create -f ../../dist/compiler-`cat ../../VERSION`-javadoc.jar `find . -type f`)

./build-do-source-zip.sh dist

cp pom.xml dist

cmark --to html README >build/README.html
htmldoc -t pdf --webpage build/README.html >dist/compiler-`cat VERSION`-README.pdf