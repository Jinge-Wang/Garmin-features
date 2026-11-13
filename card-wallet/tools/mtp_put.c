/* Small MTP primitives for folders the watch hides from its listing.
 *
 *   mtp_put info   <object id>                      show name, size, parent
 *   mtp_put send   <parent id> <name> <local file>  send a new file, read it back, compare
 *   mtp_put delete <object id> <expected name>      delete one object after checking its name
 *   mtp_put get    <object id> <local file>         copy one object off the watch
 *
 * "send" does not delete anything. It is used first with a tiny canary file to
 * learn whether a hidden folder accepts files at all, before any real file in
 * that folder is replaced.
 */
#include <libmtp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static long long size_of(const char *p) {
  struct stat st;
  return stat(p, &st) == 0 ? (long long)st.st_size : -1;
}

static int same_bytes(const char *a, const char *b) {
  FILE *fa = fopen(a, "rb"), *fb = fopen(b, "rb");
  if (!fa || !fb) { if (fa) fclose(fa); if (fb) fclose(fb); return 0; }
  int same = 1;
  for (;;) {
    int ca = fgetc(fa), cb = fgetc(fb);
    if (ca != cb) { same = 0; break; }
    if (ca == EOF) break;
  }
  fclose(fa); fclose(fb);
  return same;
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "usage: %s info|send|delete|get ...\n", argv[0]);
    return 2;
  }
  const char *cmd = argv[1];
  LIBMTP_Init();
  LIBMTP_raw_device_t *raw = NULL; int n = 0;
  if (LIBMTP_Detect_Raw_Devices(&raw, &n) != LIBMTP_ERROR_NONE || n == 0) {
    fprintf(stderr, "no device found\n"); return 1;
  }
  LIBMTP_mtpdevice_t *dev = LIBMTP_Open_Raw_Device_Uncached(&raw[0]);
  if (!dev) { fprintf(stderr, "could not open the device\n"); return 1; }
  int rc = 1;

  if (strcmp(cmd, "info") == 0) {
    uint32_t id = (uint32_t)strtoul(argv[2], NULL, 10);
    LIBMTP_file_t *m = LIBMTP_Get_Filemetadata(dev, id);
    if (!m) { fprintf(stderr, "object %u does not answer\n", id); goto out; }
    printf("%u\t%s\t%llu bytes\tparent %u\tstorage 0x%08x\n", id, m->filename,
           (unsigned long long)m->filesize, m->parent_id, m->storage_id);
    LIBMTP_destroy_file_t(m);
    rc = 0;
  } else if (strcmp(cmd, "send") == 0 && argc == 5) {
    uint32_t parent = (uint32_t)strtoul(argv[2], NULL, 10);
    const char *name = argv[3], *local = argv[4];
    if (size_of(local) < 0) { fprintf(stderr, "local file missing\n"); goto out; }
    LIBMTP_file_t *p = LIBMTP_Get_Filemetadata(dev, parent);
    if (!p) { fprintf(stderr, "parent %u does not answer\n", parent); goto out; }
    uint32_t storage = p->storage_id;
    printf("parent %u is \"%s\"\n", parent, p->filename);
    LIBMTP_destroy_file_t(p);
    LIBMTP_file_t *f = LIBMTP_new_file_t();
    f->filename = strdup(name);
    f->filesize = (uint64_t)size_of(local);
    f->filetype = LIBMTP_FILETYPE_UNKNOWN;
    f->parent_id = parent;
    f->storage_id = storage;
    if (LIBMTP_Send_File_From_File(dev, local, f, NULL, NULL) != 0) {
      fprintf(stderr, "send refused\n");
      LIBMTP_Dump_Errorstack(dev);
      LIBMTP_destroy_file_t(f);
      goto out;
    }
    uint32_t id = f->item_id;
    LIBMTP_destroy_file_t(f);
    printf("sent as object %u\n", id);
    char back[1100];
    snprintf(back, sizeof back, "%s.read-back", local);
    if (LIBMTP_Get_File_To_File(dev, id, back, NULL, NULL) != 0 || !same_bytes(back, local)) {
      fprintf(stderr, "read-back does not match\n"); remove(back); goto out;
    }
    remove(back);
    printf("read-back matches (%lld bytes)\n", size_of(local));
    rc = 0;
  } else if (strcmp(cmd, "delete") == 0 && argc == 4) {
    uint32_t id = (uint32_t)strtoul(argv[2], NULL, 10);
    LIBMTP_file_t *m = LIBMTP_Get_Filemetadata(dev, id);
    if (!m) { fprintf(stderr, "object %u does not answer\n", id); goto out; }
    if (strcmp(m->filename, argv[3]) != 0) {
      fprintf(stderr, "object %u is \"%s\", not \"%s\"; nothing deleted\n", id, m->filename, argv[3]);
      LIBMTP_destroy_file_t(m); goto out;
    }
    LIBMTP_destroy_file_t(m);
    if (LIBMTP_Delete_Object(dev, id) != 0) {
      fprintf(stderr, "delete refused\n"); LIBMTP_Dump_Errorstack(dev); goto out;
    }
    printf("deleted object %u (%s)\n", id, argv[3]);
    rc = 0;
  } else if (strcmp(cmd, "get") == 0 && argc == 4) {
    uint32_t id = (uint32_t)strtoul(argv[2], NULL, 10);
    if (LIBMTP_Get_File_To_File(dev, id, argv[3], NULL, NULL) != 0) {
      fprintf(stderr, "could not read object %u\n", id); goto out;
    }
    printf("copied object %u to %s (%lld bytes)\n", id, argv[3], size_of(argv[3]));
    rc = 0;
  } else {
    fprintf(stderr, "bad arguments\n");
  }

out:
  LIBMTP_Release_Device(dev);
  free(raw);
  return rc;
}
