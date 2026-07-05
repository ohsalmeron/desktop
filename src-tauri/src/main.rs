// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
  // Force X11 backend to avoid Wayland protocol errors
  std::env::set_var("GDK_BACKEND", "x11");
  app_lib::run();
}
