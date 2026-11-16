import 'dart:io';

import '../../tool/build_wine_index.dart';

/// Rows chosen to exercise ranking and every mapped column value.
const fixtureCsv =
    'WineID,WineName,Type,Elaborate,Grapes,ABV,Body,Acidity,Code,Country,RegionName,WineryName\n'
    '1,Margaux du Château Margaux,Red,Assemblage/Blend,"[\'Cabernet Sauvignon\', \'Merlot\']",13.5,Full-bodied,Medium,FR,France,Margaux,Château Margaux\n'
    '2,Château Margaux (Premier Grand Cru Classé),Red,Assemblage/Blend,"[\'Cabernet Sauvignon\', \'Merlot\']",13.5,Very full-bodied,High,FR,France,Margaux,Château Margaux\n'
    '3,Pavillon Blanc du Château Margaux,White,Varietal/100%,[\'Sauvignon Blanc\'],13.0,Medium-bodied,Low,FR,France,Margaux,Château Margaux\n'
    '4,Margaux,Red,Assemblage/Blend,[\'Merlot\'],13.0,Light-bodied,High,FR,France,Margaux,Château Angludet\n'
    '5,Vintage Port,Dessert/Port,Assemblage/Blend,[\'Touriga Nacional\'],20.0,Very full-bodied,Medium,PT,Portugal,Porto,Taylor\'s\n'
    '6,Moscato d\'Asti,Sparkling,Varietal/100%,[\'Muscat/Moscato\'],5.5,Light-bodied,High,IT,Italy,Asti,Vietti\n'
    '7,Tavel Rosé,Rosé,Assemblage/Blend,"[\'Grenache\', \'Cinsault\']",13.5,Very light-bodied,Medium,FR,France,Tavel,Château d\'Aqueria\n'
    '8,Sauternes,Dessert,Assemblage/Blend,[\'Sémillon\'],14.0,Full-bodied,High,FR,France,Sauternes,Château Suduiraut\n'
    '9,Weißburgunder Trocken,White,Varietal/100%,[\'Pinot Blanc\'],12.5,Medium-bodied,High,DE,Germany,Pfalz,Weingut Müller\n'
    '10,Mystery Cuvée,Orange,,[],,Medium,Very high,,,,\n';

/// Builds the fixture index in a fresh temp dir; returns the db path.
String buildFixtureIndex(Directory dir) {
  final csv = File('${dir.path}/fixture.csv')..writeAsStringSync(fixtureCsv);
  final db = '${dir.path}/fixture.db';
  buildWineIndex(csv.path, db);
  return db;
}
