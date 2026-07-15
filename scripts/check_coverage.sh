#!/usr/bin/env bash
set -euo pipefail

MIN_COVERAGE=85
LCOV_RAW="coverage/lcov.info"
LCOV_CLEAN="coverage/clean_lcov.info"

echo "==> Ejecutando pruebas de Flutter con cobertura..."
flutter test --coverage > /dev/null

if [ ! -f "$LCOV_RAW" ]; then
  echo "ERROR: No se generó el archivo $LCOV_RAW. Abortando."
  exit 1
fi

echo "==> Filtrando archivos autogenerados y de configuración..."
lcov --remove "$LCOV_RAW" \
  'lib/main.dart' \
  'lib/*/*.g.dart' \
  'lib/*/*.freezed.dart' \
  'lib/generated/*' \
  -o "$LCOV_CLEAN" \
  --ignore-errors unused > /dev/null

echo "==> Calculando porcentaje de cobertura neta..."
SUMMARY_LINE=$(lcov --summary "$LCOV_CLEAN" 2>/dev/null | grep "lines" || true)

if [ -z "$SUMMARY_LINE" ]; then
  echo "ERROR: No se pudo calcular el resumen de cobertura."
  exit 1
fi

COVERAGE=$(echo "$SUMMARY_LINE" | grep -oE '[0-9]+\.[0-9]+%' | head -1 | tr -d '%')

if [ -z "$COVERAGE" ]; then
  echo "ERROR: No se pudo parsear el porcentaje de cobertura."
  exit 1
fi

echo "==> Cobertura neta obtenida: ${COVERAGE}%"
echo "==> Umbral mínimo requerido: ${MIN_COVERAGE}%"

PASSES=$(echo "$COVERAGE >= $MIN_COVERAGE" | bc -l)

if [ "$PASSES" -eq 1 ]; then
  echo "✅ Cobertura aprobada (${COVERAGE}% >= ${MIN_COVERAGE}%)."
  exit 0
else
  echo "❌ ERROR: La cobertura (${COVERAGE}%) está por debajo del umbral de ${MIN_COVERAGE}%."
  exit 1
fi