#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDLib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <poll.h>
#include <time.h>
#include <unistd.h>

struct Model {
    int vendor, product;
    char name[256];
};

static void read_string(IOHIDDeviceRef device, CFStringRef key, char *output, size_t size)
{
    CFTypeRef property = IOHIDDeviceGetProperty(device, key);
    output[0] = '\0';
    if (property && CFGetTypeID(property) == CFStringGetTypeID() &&
        !CFStringGetCString(property, output, size, kCFStringEncodingUTF8)) output[0] = '\0';
}

static int read_id(IOHIDDeviceRef device, CFStringRef key)
{
    CFTypeRef property = IOHIDDeviceGetProperty(device, key);
    int id = 0;
    if (property && CFGetTypeID(property) == CFNumberGetTypeID()) {
        CFNumberGetValue(property, kCFNumberIntType, &id);
    }
    return id;
}

static void strip_channel(char *name)
{
    const char *suffixes[] = {" BT-", " BT ", " Bluetooth-", " Bluetooth "};
    size_t length = strlen(name);
    if (length == 0 || name[length - 1] < '1' || name[length - 1] > '9') return;
    for (size_t i = 0; i < sizeof(suffixes) / sizeof(*suffixes); ++i) {
        size_t suffix_length = strlen(suffixes[i]);
        if (length > suffix_length + 1 &&
            strncasecmp(name + length - suffix_length - 1, suffixes[i], suffix_length) == 0) {
            name[length - suffix_length - 1] = '\0';
            return;
        }
    }
}

static const char *mouse_model(const char *name)
{
    if (strncasecmp(name, "Logitech ", 9) == 0) name += 9;
    else if (strncasecmp(name, "Logi ", 5) == 0) name += 5;
    if (strcasecmp(name, "MX Master 4 B") == 0) return "MX Master 4";
    return name;
}

static bool read_model(IOHIDDeviceRef device, struct Model *model, bool mouse)
{
    char transport[64];
    read_string(device, CFSTR(kIOHIDTransportKey), transport, sizeof(transport));
    if (strncasecmp(transport, "Bluetooth", 9) != 0) return false;
    model->vendor = read_id(device, CFSTR(kIOHIDVendorIDKey));
    model->product = read_id(device, CFSTR(kIOHIDProductIDKey));
    if (mouse && model->vendor != 0x046d) return false;
    read_string(device, CFSTR(kIOHIDProductKey), model->name, sizeof(model->name));
    return model->name[0] && !strpbrk(model->name, "\r\n\t");
}

static int enumerate(bool mouse, const char *requested, struct Model *selected,
    IOHIDDeviceRef *output, bool list)
{
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) return 2;
    const void *keys[] = {CFSTR(kIOHIDPrimaryUsagePageKey), CFSTR(kIOHIDPrimaryUsageKey)};
    int values[] = {1, mouse ? 2 : 6};
    const void *properties[2];
    for (size_t i = 0; i < 2; ++i) {
        properties[i] = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &values[i]);
    }
    CFDictionaryRef matching = CFDictionaryCreate(kCFAllocatorDefault, keys, properties, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    for (size_t i = 0; i < 2; ++i) CFRelease(properties[i]);
    if (!matching) {
        CFRelease(manager);
        return 2;
    }
    IOHIDManagerSetDeviceMatching(manager, matching);
    CFRelease(matching);

    CFSetRef devices = IOHIDManagerCopyDevices(manager);
    CFIndex count = devices ? CFSetGetCount(devices) : 0;
    const void **entries = count ? calloc((size_t)count, sizeof(*entries)) : NULL;
    int result = count && !entries ? 2 : 1;
    const void *candidate = NULL, *legacy = NULL;
    struct Model candidate_model = {0}, legacy_model = {0};
    unsigned int candidates = 0, legacy_count = 0;
    if (entries) CFSetGetValues(devices, entries);
    for (CFIndex i = 0; entries && i < count; ++i) {
        struct Model model;
        if (!read_model((IOHIDDeviceRef)entries[i], &model, mouse)) continue;
        if (list) {
            printf("%04x:%04x\t%s\n", (unsigned)model.vendor, (unsigned)model.product, model.name);
            result = 0;
            continue;
        }
        if (mouse) {
            if (strcasecmp(mouse_model(model.name), requested) == 0) result = 0;
            continue;
        }
        bool requested_match = requested && strcasecmp(model.name, requested) == 0;
        strip_channel(model.name);
        if (requested && !requested_match && strcasecmp(model.name, requested) != 0) continue;
        if (selected->name[0] && (model.vendor != selected->vendor || model.product != selected->product ||
            strcasecmp(model.name, selected->name) != 0)) continue;
        candidate = entries[i];
        candidate_model = model;
        ++candidates;
        if (model.vendor == 0x3151 && model.product == 0x5027 && strcasecmp(model.name, "ACH105") == 0) {
            legacy = entries[i];
            legacy_model = model;
            ++legacy_count;
        }
    }
    if (!mouse && !list) {
        if (candidates == 1) {
            *output = (IOHIDDeviceRef)CFRetain(candidate);
            *selected = candidate_model;
            result = 0;
        } else if (candidates > 1 && !requested && !selected->name[0] && legacy_count == 1) {
            *output = (IOHIDDeviceRef)CFRetain(legacy);
            *selected = legacy_model;
            result = 0;
        } else if (candidates > 1) {
            result = 2;
        }
    }
    free(entries);
    if (devices) CFRelease(devices);
    CFRelease(manager);
    return result;
}

static IOHIDDeviceRef find_keyboard(const char *requested, struct Model *model)
{
    IOHIDDeviceRef device = NULL;
    int result = enumerate(false, requested, model, &device, false);
    if (result == 1) fprintf(stderr, "No matching Bluetooth keyboard is connected to this Mac.\n");
    if (result == 2) fprintf(stderr, "Could not select one Bluetooth keyboard; use --list-keyboards and --keyboard NAME.\n");
    return device;
}

static void key_changed(void *context, IOReturn result, void *sender, IOHIDValueRef value)
{
    (void)context;
    (void)sender;
    if (result != kIOReturnSuccess) return;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (IOHIDElementGetUsagePage(element) != 7) return;
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex down = IOHIDValueGetIntegerValue(value);
    if (usage >= 4 && usage <= 255 && (down == 0 || down == 1)) {
        printf("KEY %u %ld\n", usage, (long)down);
        fflush(stdout);
    }
}

static void release_keyboard(IOHIDDeviceRef keyboard)
{
    IOHIDDeviceUnscheduleFromRunLoop(keyboard, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(keyboard, kIOHIDOptionsTypeSeizeDevice);
    CFRelease(keyboard);
}

static int relay(const char *requested)
{
    struct Model model = {0};
    IOHIDDeviceRef keyboard = NULL;
    struct pollfd input = {STDIN_FILENO, POLLIN, 0};
    double lease = 0;
    puts("STARTED");
    fflush(stdout);
    for (;;) {
        double now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1000000000.0;
        if (keyboard) {
            if (now > lease) break;
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
        }
        int ready = poll(&input, 1, keyboard ? 0 : 1000);
        if (ready < 0) break;
        if (ready == 0) continue;
        char command;
        if (read(STDIN_FILENO, &command, 1) != 1) break;
        if (command == '0' && keyboard) {
            release_keyboard(keyboard);
            keyboard = NULL;
        } else if (command == '2' && keyboard) {
            lease = now + 3;
        } else if (command == '1' && !keyboard) {
            keyboard = find_keyboard(model.name[0] ? NULL : requested, &model);
            if (keyboard && IOHIDDeviceOpen(keyboard, kIOHIDOptionsTypeSeizeDevice) == kIOReturnSuccess) {
                IOHIDDeviceRegisterInputValueCallback(keyboard, key_changed, NULL);
                IOHIDDeviceScheduleWithRunLoop(keyboard, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                lease = now + 3;
                puts("READY");
            } else {
                if (keyboard) CFRelease(keyboard);
                keyboard = NULL;
                puts("FAILED");
            }
            fflush(stdout);
        }
    }
    if (keyboard) release_keyboard(keyboard);
    return 0;
}

int main(int argc, char **argv)
{
    const char *requested = argc == 3 ? argv[2] : NULL;
    if (argc == 2 && strcmp(argv[1], "list-keyboards") == 0) return enumerate(false, NULL, NULL, NULL, true);
    if (argc == 2 && strcmp(argv[1], "list-mice") == 0) return enumerate(true, NULL, NULL, NULL, true);
    if (argc == 3 && strcmp(argv[1], "mouse") == 0) return enumerate(true, mouse_model(requested), NULL, NULL, false);
    if (argc >= 2 && argc <= 3 && strcmp(argv[1], "relay") == 0) return relay(requested);
    if (argc < 2 || argc > 3 || (strcmp(argv[1], "check") != 0 && strcmp(argv[1], "seize-check") != 0 &&
        strcmp(argv[1], "select") != 0)) {
        fprintf(stderr, "usage: abko-access list-keyboards|list-mice|mouse NAME|select [NAME]|check [NAME]|seize-check [NAME]|relay [NAME]\n");
        return 2;
    }
    struct Model model = {0};
    IOHIDDeviceRef keyboard = find_keyboard(requested, &model);
    if (!keyboard) return 1;
    if (strcmp(argv[1], "select") == 0) {
        puts(model.name);
        CFRelease(keyboard);
        return 0;
    }
    bool seize = strcmp(argv[1], "seize-check") == 0;
    IOOptionBits options = seize ? kIOHIDOptionsTypeSeizeDevice : kIOHIDOptionsTypeNone;
    IOReturn result = IOHIDDeviceOpen(keyboard, options);
    if (result == kIOReturnSuccess) {
        result = IOHIDDeviceClose(keyboard, options);
        if (result == kIOReturnSuccess) {
            printf("%s %s open and release succeeded\n", model.name, seize ? "exclusive" : "shared");
        } else {
            fprintf(stderr, "ACH105 close failed: 0x%08x\n", (unsigned)result);
        }
    } else {
        fprintf(stderr, "ACH105 %s open failed: 0x%08x\n", seize ? "exclusive" : "shared", (unsigned)result);
    }

    CFRelease(keyboard);
    return result == kIOReturnSuccess ? 0 : 1;
}
