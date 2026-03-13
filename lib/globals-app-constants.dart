// ignore_for_file: file_names

import 'package:flutter/material.dart';

// Forward declaration for app rebuild function
void Function()? rebuildApp;
// Home screen refresh hook (set by HomeScreen).
void Function()? refreshHome;

// Font setups
const double fsSmall = 14;
const double fsNormal = 16;
const double fsMedium = 18;
const double fsLarge = 20;
const double fsTitle = 24;
const FontWeight fwNormal = FontWeight.normal;
const FontWeight fwMedium = FontWeight.w500;
const FontWeight fwBold = FontWeight.bold;
