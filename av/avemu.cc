#include "av.h"

/**
 * -d Запустить запись debug.log с самого начала
 */

int main(int argc, char* argv[]) {

    AVR* app = new AVR(640, 400, 1, 25);
    app->load(argc, argv);

    while (app->main()) app->frame();
    return 0;
}
