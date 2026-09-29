#include <sys/stat.h>
#include <errno.h>
#include <stdint.h>

extern uint32_t _end;
extern uint32_t _estack;

static uint8_t *heap_end;

caddr_t _sbrk(int incr)
{
  uint8_t *prev;
  if (heap_end == 0)
  {
    heap_end = (uint8_t *)&_end;
  }
  prev = heap_end;
  if ((heap_end + incr) > (uint8_t *)((uint32_t)&_estack - 0x400U))
  {
    errno = ENOMEM;
    return (caddr_t)-1;
  }
  heap_end += incr;
  return (caddr_t)prev;
}

int _close(int file) { (void)file; return -1; }
int _fstat(int file, struct stat *st) { (void)file; st->st_mode = S_IFCHR; return 0; }
int _isatty(int file) { (void)file; return 1; }
int _lseek(int file, int ptr, int dir) { (void)file; (void)ptr; (void)dir; return 0; }
int _read(int file, char *ptr, int len) { (void)file; (void)ptr; (void)len; return 0; }
int _write(int file, char *ptr, int len) { (void)file; (void)ptr; return len; }
void _exit(int status) { (void)status; while (1) {} }
int _kill(int pid, int sig) { (void)pid; (void)sig; errno = EINVAL; return -1; }
int _getpid(void) { return 1; }
