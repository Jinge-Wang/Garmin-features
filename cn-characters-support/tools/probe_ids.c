/* Read-only probe: ask the watch for object info on every id in a range.
 * The normal listing only returns what the watch chooses to enumerate; an id
 * that answers here but is absent from the listing is a hidden object.
 *
 * usage: probe_ids <first id> <last id> [<first> <last> ...]
 * output: id <tab> name <tab> size <tab> parent id <tab> type
 */
#include <libmtp.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  if (argc < 3 || (argc - 1) % 2 != 0) {
    fprintf(stderr, "usage: %s <first> <last> [...]\n", argv[0]);
    return 2;
  }
  LIBMTP_Init();
  LIBMTP_raw_device_t *raw = NULL;
  int n = 0;
  LIBMTP_error_number_t err = LIBMTP_Detect_Raw_Devices(&raw, &n);
  if (err != LIBMTP_ERROR_NONE || n == 0) {
    fprintf(stderr, "no device found (code %d)\n", (int)err);
    return 1;
  }
  LIBMTP_mtpdevice_t *dev = LIBMTP_Open_Raw_Device_Uncached(&raw[0]);
  if (!dev) {
    fprintf(stderr, "could not open the device\n");
    return 1;
  }
  for (int a = 1; a + 1 < argc; a += 2) {
    unsigned long lo = strtoul(argv[a], NULL, 10);
    unsigned long hi = strtoul(argv[a + 1], NULL, 10);
    for (unsigned long id = lo; id <= hi; id++) {
      LIBMTP_file_t *f = LIBMTP_Get_Filemetadata(dev, (uint32_t)id);
      if (f) {
        printf("%lu\t%s\t%llu\t%u\t%d\n", id, f->filename ? f->filename : "(null)",
               (unsigned long long)f->filesize, f->parent_id, (int)f->filetype);
        LIBMTP_destroy_file_t(f);
      }
      LIBMTP_Clear_Errorstack(dev);
    }
  }
  LIBMTP_Release_Device(dev);
  free(raw);
  return 0;
}
