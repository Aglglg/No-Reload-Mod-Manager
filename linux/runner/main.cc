#include "my_application.h"

int main(int argc, char** argv) {
  // many things just doesnt work on wayland
  // global hotkey, window auto focus, remove app icon from taskbar, window set position,
  setenv("GDK_BACKEND", "x11", 1);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
