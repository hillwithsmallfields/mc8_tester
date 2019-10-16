#ifndef WIRING_H
#define WIRING_H

typedef struct connector {
  char *label;
  int wire_indices[8];
} connector;

#endif
