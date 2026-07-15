#!/bin/bash
set -e

MIN_COVERAGE=85
LCOV_FILE="coverage/lcov.info"
CLEAN_LCOV_FILE="coverage/clean_lcov.info"

echo "-> Ejecutando pruebas de Flutter con cobertura..."
flutter test --coverage

if [ ! -f "$LCOV_FILE" ]; then
  echo "ERROR: no se generó el archivo $LCOV_FILE"
  exit 1
fi

echo "-> Filtrando archivos autogenerados..."
lcov --remove "$LCOV_FILE" \
  'lib/main.dart' \
  'lib/*/*.g.dart' \
  'lib/*/*.freezed.dart' \
  'lib/generated/*' \
  -o "$CLEAN_LCOV_FILE" \
  --ignore-errors unused

echo "-> Calculando porcentaje de cobertura neta..."
COVERAGE_SUMMARY=$(lcov --summary "$CLEAN_LCOV_FILE" 2>&1)
COVERAGE_PERCENT=$(echo "$COVERAGE_SUMMARY" | grep "lines" | grep -oP '\d+\.\d+(?=%)')

if [ -z "$COVERAGE_PERCENT" ]; then
  echo "ERROR: no se pudo calcular el porcentaje de cobertura"
  exit 1
fi

echo "-> Cobertura neta obtenida: ${COVERAGE_PERCENT}%"

RESULT=$(echo "$COVERAGE_PERCENT < $MIN_COVERAGE" | bc)

if [ "$RESULT" -eq 1 ]; then
  echo "FALLO: la cobertura (${COVERAGE_PERCENT}%) es menor al mínimo requerido (${MIN_COVERAGE}%)."
  exit 1
else
  echo "EXITO: la cobertura (${COVERAGE_PERCENT}%) cumple con el mínimo requerido (${MIN_COVERAGE}%)."
  exit 0
fi