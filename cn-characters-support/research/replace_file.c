/* Replace one file on the watch over MTP, with checks before and after.
 *
 * MTP has no overwrite: the old object is deleted and a new one is sent.
 * Steps:
 *   1. find the object by id and confirm its name and parent folder;
 *   2. download it and compare it byte for byte with the local original
 *      (so the copy kept on the Mac really is what the watch holds);
 *   3. delete it, send the new file under the same name into the same folder;
 *   4. download the new object and compare it with what was sent.
 * If the send fails after the delete, the original is sent back.
 *
 * usage: replace_file <object id> <name on watch> <local original> <local new>
 * Add "--dry-run" as a fifth argument to stop after step 2.
 */
#include <libmtp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

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

static long long size_of(const char *p) {
  struct stat st;
  return stat(p, &st) == 0 ? (long long)st.st_size : -1;
}

static int send_one(LIBMTP_mtpdevice_t *dev, const char *local, const char *name,
                    uint32_t parent, uint32_t storage, uint32_t *new_id) {
  LIBMTP_file_t *f = LIBMTP_new_file_t();
  f->filename = strdup(name);
  f->filesize = (uint64_t)size_of(local);
  f->filetype = LIBMTP_FILETYPE_UNKNOWN;
  f->parent_id = parent;
  f->storage_id = storage;
  int rc = LIBMTP_Send_File_From_File(dev, local, f, NULL, NULL);
  if (rc == 0 && new_id) *new_id = f->item_id;
  LIBMTP_destroy_file_t(f);
  return rc;
}

int main(int argc, char **argv) {
  if (argc < 5) {
    fprintf(stderr, "usage: %s <id> <name> <local original> <local new> [--dry-run]\n", argv[0]);
    return 2;
  }
  uint32_t id = (uint32_t)strtoul(argv[1], NULL, 10);
  const char *name = argv[2], *orig = argv[3], *fresh = argv[4];
  int dry = argc > 5 && strcmp(argv[5], "--dry-run") == 0;
  char tmp_before[1100], tmp_after[1100];
  snprintf(tmp_before, sizeof tmp_before, "%s.on-watch-before", fresh);
  snprintf(tmp_after, sizeof tmp_after, "%s.on-watch-after", fresh);

  if (size_of(orig) < 0 || size_of(fresh) < 0) { fprintf(stderr, "local file missing\n"); return 2; }

  LIBMTP_Init();
  LIBMTP_raw_device_t *raw = NULL; int n = 0;
  if (LIBMTP_Detect_Raw_Devices(&raw, &n) != LIBMTP_ERROR_NONE || n == 0) {
    fprintf(stderr, "no device found\n"); return 1;
  }
  LIBMTP_mtpdevice_t *dev = LIBMTP_Open_Raw_Device_Uncached(&raw[0]);
  if (!dev) { fprintf(stderr, "could not open the device\n"); return 1; }

  int rc = 1;
  LIBMTP_file_t *meta = LIBMTP_Get_Filemetadata(dev, id);
  if (!meta) { fprintf(stderr, "object %u not found on the watch\n", id); goto out; }
  uint32_t parent = meta->parent_id, storage = meta->storage_id;
  printf("1. object %u is \"%s\", %llu bytes, parent %u\n", id, meta->filename,
         (unsigned long long)meta->filesize, parent);
  if (strcmp(meta->filename, name) != 0) {
    fprintf(stderr, "name mismatch: expected \"%s\"; nothing changed\n", name);
    LIBMTP_destroy_file_t(meta); goto out;
  }
  LIBMTP_destroy_file_t(meta);

  if (LIBMTP_Get_File_To_File(dev, id, tmp_before, NULL, NULL) != 0) {
    fprintf(stderr, "could not read the current file; nothing changed\n"); goto out;
  }
  if (!same_bytes(tmp_before, orig)) {
    fprintf(stderr, "the file on the watch differs from the local original; nothing changed\n"); goto out;
  }
  printf("2. file on the watch matches the local original byte for byte\n");
  if (dry) { printf("dry run: stopping before any change\n"); rc = 0; goto out; }

  if (LIBMTP_Delete_Object(dev, id) != 0) {
    fprintf(stderr, "delete failed; nothing changed\n");
    LIBMTP_Dump_Errorstack(dev); goto out;
  }
  uint32_t new_id = 0;
  if (send_one(dev, fresh, name, parent, storage, &new_id) != 0) {
    fprintf(stderr, "send failed after delete; putting the original back\n");
    LIBMTP_Dump_Errorstack(dev); LIBMTP_Clear_Errorstack(dev);
    if (send_one(dev, orig, name, parent, storage, &new_id) != 0) {
      fprintf(stderr, "RESTORE FAILED: the watch has no %s now; send %s manually\n", name, orig);
      LIBMTP_Dump_Errorstack(dev);
    } else {
      fprintf(stderr, "original restored as object %u\n", new_id);
    }
    goto out;
  }
  printf("3. old object deleted, new file sent as object %u\n", new_id);

  if (LIBMTP_Get_File_To_File(dev, new_id, tmp_after, NULL, NULL) != 0 || !same_bytes(tmp_after, fresh)) {
    fprintf(stderr, "read-back does not match what was sent\n"); goto out;
  }
  printf("4. read-back matches: the watch now holds the new %s (%lld bytes)\n", name, size_of(fresh));
  rc = 0;

out:
  LIBMTP_Release_Device(dev);
  free(raw);
  return rc;
}
