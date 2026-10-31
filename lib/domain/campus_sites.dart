import 'campus_schema.dart';

const campusSites = <String, CampusSite>{
  'main': CampusSite(
    title: 'Основной кампус',
    width: 1000,
    height: 880,
    roads: [
      Road(x: 0, y: 78, w: 1000, h: 52, name: 'просп. 25-летия РККА', atX: 640, atY: 112),
      Road(x: 40, y: 0, w: 75, h: 880, name: 'ул. Кобозева', atX: 80, atY: 470, rotate: -90),
      Road(x: 905, y: 0, w: 60, h: 880, name: 'ул. Артёма', atX: 938, atY: 420, rotate: 90),
      Road(x: 0, y: 745, w: 1000, h: 50),
    ],
    decor: [
      Decor(x: 612, y: 200, w: 130, h: 62),
      Decor(x: 396, y: 268, w: 80, h: 48),
      Decor(x: 410, y: 334, w: 64, h: 48),
      Decor(x: 480, y: 314, w: 62, h: 62),
      Decor(x: 384, y: 402, w: 88, h: 56),
    ],
    buildings: [
      Block(id: '8', points: '172,128 335,112 350,238 190,252', centerX: 262, centerY: 185),
      Block(id: '2', points: '790,218 845,214 862,385 800,392', centerX: 826, centerY: 300),
      Block(id: '4', points: '142,288 212,284 210,478 142,482', centerX: 177, centerY: 383),
      Block(id: '5', points: '132,490 355,488 354,598 130,602', centerX: 243, centerY: 545),
      Block(id: '9', points: '325,530 472,524 474,694 325,695', centerX: 398, centerY: 610),
      Block(id: '1', points: '815,392 862,392 888,700 828,704 826,640 672,640 672,560 600,552 602,505 690,525 745,520 745,428 815,425', centerX: 852, centerY: 545),
      Block(id: 'baz', points: '542,640 668,632 672,716 545,722', centerX: 606, centerY: 676),
    ],
  ),
  'artema131': CampusSite(
    title: 'Корпус 11',
    width: 1000,
    height: 620,
    roads: [
      Road(x: 0, y: 60, w: 1000, h: 50, name: 'просп. Ватутина', atX: 660, atY: 92),
      Road(x: 60, y: 0, w: 90, h: 620, name: 'ул. Артёма', atX: 105, atY: 340, rotate: -90),
    ],
    decor: [
      Decor(x: 485, y: 145, w: 265, h: 130, label: 'Бассейн'),
      Decor(x: 560, y: 310, w: 385, h: 230, label: 'Манеж'),
    ],
    buildings: [
      Block(id: '11', points: '300,115 405,150 385,385 310,465 205,420 235,315', centerX: 315, centerY: 300),
    ],
  ),
};

