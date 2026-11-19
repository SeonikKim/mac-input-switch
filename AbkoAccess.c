#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDLib.h>
#include <stdio.h>
#include <string.h>
#include <poll.h>
#include <time.h>
#include <unistd.h>

static IOHIDDeviceRef find_keyboard(void)
{
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) return NULL;

    const void *keys[] = {CFSTR(kIOHIDVendorIDKey), CFSTR(kIOHIDProductIDKey),
        CFSTR(kIOHIDPrimaryUsagePageKey), CFSTR(kIOHIDPrimaryUsageKey), CFSTR(kIOHIDProductKey)};
    int values[] = {0x3151, 0x5027, 1, 6};
    const void *properties[5];
    for (size_t i = 0; i < 4; ++i) {
        properties[i] = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &values[i]);
    }
    properties[4] = CFSTR("ACH105 BT-3");
    CFDictionaryRef matching = CFDictionaryCreate(kCFAllocatorDefault, keys, properties, 5,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    for (size_t i = 0; i < 4; ++i) CFRelease(properties[i]);
    if (!matching) {
        CFRelease(manager);
        return NULL;
    }
    IOHIDManagerSetDeviceMatching(manager, matching);
    CFRelease(matching);

    CFSetRef devices = IOHIDManagerCopyDevices(manager);
    CFIndex count = devices ? CFSetGetCount(devices) : 0;
    if (count != 1) {
        fprintf(stderr, "Expected exactly one ACH105 BT-3 keyboard, found %ld\n", (long)count);
        if (devices) CFRelease(devices);
        CFRelease(manager);
        return NULL;
    }

    const void *entry;
    CFSetGetValues(devices, &entry);
    IOHIDDeviceRef keyboard = (IOHIDDeviceRef)CFRetain(entry);
    CFRelease(devices);
    CFRelease(manager);
    return keyboard;
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

static int relay(void)
{
    IOHIDDeviceRef keyboard = NULL;
    struct pollfd input = {STDIN_FILENO, POLLIN, 0};
    double lease = 0;
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
            keyboard = find_keyboard();
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
    if (argc == 2 && strcmp(argv[1], "relay") == 0) return relay();
    if (argc != 2 || (strcmp(argv[1], "check") != 0 && strcmp(argv[1], "seize-check") != 0)) {
        fprintf(stderr, "usage: abko-access check|seize-check|relay\n");
        return 2;
    }
    IOHIDDeviceRef keyboard = find_keyboard();
    if (!keyboard) return 1;
    bool seize = strcmp(argv[1], "seize-check") == 0;
    IOOptionBits options = seize ? kIOHIDOptionsTypeSeizeDevice : kIOHIDOptionsTypeNone;
    IOReturn result = IOHIDDeviceOpen(keyboard, options);
    if (result == kIOReturnSuccess) {
        result = IOHIDDeviceClose(keyboard, options);
        if (result == kIOReturnSuccess) {
            puts(seize ? "ACH105 exclusive open and release succeeded" : "ACH105 shared open and release succeeded");
        } else {
            fprintf(stderr, "ACH105 close failed: 0x%08x\n", (unsigned)result);
        }
    } else {
        fprintf(stderr, "ACH105 %s open failed: 0x%08x\n", seize ? "exclusive" : "shared", (unsigned)result);
    }

    CFRelease(keyboard);
    return result == kIOReturnSuccess ? 0 : 1;
}
