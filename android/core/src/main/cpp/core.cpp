#include <jni.h>
#include <cstdlib>
#include <cstring>

#ifdef LIBCLASH

#include "jni_helper.h"
#include "libclash.h"
#include "bride.h"

static void throw_out_of_memory(JNIEnv *env) {
    const auto exception = find_class("java/lang/OutOfMemoryError");
    if (exception != nullptr) {
        env->ThrowNew(exception, "malloc failed");
    }
}

static char *empty_string() {
    return strdup("");
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_startTun(JNIEnv *env, jobject thiz, jint fd, jobject cb,
                                         jstring stack, jstring address, jstring dns) {
    const auto interface = new_global(cb);
    const auto stackValue = get_string(stack);
    if (stackValue == nullptr) {
        del_global(interface);
        throw_out_of_memory(env);
        return;
    }
    const auto addressValue = get_string(address);
    if (addressValue == nullptr) {
        free(stackValue);
        del_global(interface);
        throw_out_of_memory(env);
        return;
    }
    const auto dnsValue = get_string(dns);
    if (dnsValue == nullptr) {
        free(stackValue);
        free(addressValue);
        del_global(interface);
        throw_out_of_memory(env);
        return;
    }
    startTUN(interface, fd, stackValue, addressValue, dnsValue);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_stopTun(JNIEnv *env, jobject thiz) {
    stopTun();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_forceGC(JNIEnv *env, jobject thiz) {
    forceGC();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_updateDNS(JNIEnv *env, jobject thiz, jstring dns) {
    const auto dnsValue = get_string(dns);
    if (dnsValue == nullptr) {
        throw_out_of_memory(env);
        return;
    }
    updateDns(dnsValue);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_invokeAction(JNIEnv *env, jobject thiz, jstring data, jobject cb) {
    const auto interface = new_global(cb);
    const auto dataValue = get_string(data);
    if (dataValue == nullptr) {
        del_global(interface);
        throw_out_of_memory(env);
        return;
    }
    invokeAction(interface, dataValue);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_setEventListener(JNIEnv *env, jobject thiz, jobject cb) {
    if (cb != nullptr) {
        const auto interface = new_global(cb);
        setEventListener(interface);
    } else {
        setEventListener(nullptr);
    }
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTraffic(JNIEnv *env, jobject thiz,
                                           const jboolean only_statistics_proxy) {
    return new_string(getTraffic(only_statistics_proxy));
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTotalTraffic(JNIEnv *env, jobject thiz,
                                                const jboolean only_statistics_proxy) {
    return new_string(getTotalTraffic(only_statistics_proxy));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_suspended(JNIEnv *env, jobject thiz, jboolean suspended) {
    suspend(suspended);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_quickSetup(JNIEnv *env, jobject thiz, jstring init_params_string,
                                           jstring setup_params_string, jobject cb) {
    const auto interface = new_global(cb);
    const auto initParamsValue = get_string(init_params_string);
    if (initParamsValue == nullptr) {
        del_global(interface);
        throw_out_of_memory(env);
        return;
    }
    const auto setupParamsValue = get_string(setup_params_string);
    if (setupParamsValue == nullptr) {
        free(initParamsValue);
        del_global(interface);
        throw_out_of_memory(env);
        return;
    }
    quickSetup(interface, initParamsValue, setupParamsValue);
}


static jmethodID m_tun_interface_protect;
static jmethodID m_tun_interface_resolve_process;
static jmethodID m_invoke_interface_result;


static void release_jni_object_impl(void *obj) {
    ATTACH_JNI();
    del_global(static_cast<jobject>(obj));
}

static void free_string_impl(char *str) {
    free(str);
}

static void call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    ATTACH_JNI();
    env->CallVoidMethod(static_cast<jobject>(tun_interface),
                        m_tun_interface_protect,
                        fd);
}

static char *
call_tun_interface_resolve_process_impl(void *tun_interface, const int protocol,
                                        const char *source,
                                        const char *target,
                                        const int uid) {
    if (tun_interface == nullptr) {
        return strdup("");
    }
    ATTACH_JNI();
    const auto packageName = reinterpret_cast<jstring>(env->CallObjectMethod(
            static_cast<jobject>(tun_interface),
            m_tun_interface_resolve_process,
            protocol,
            new_string(source),
            new_string(target),
            uid));
    const auto packageNameValue = get_string(packageName);
    if (packageNameValue == nullptr) {
        throw_out_of_memory(env);
        return empty_string();
    }
    return packageNameValue;
}

static void call_invoke_interface_result_impl(void *invoke_interface, const char *data) {
    ATTACH_JNI();
    env->CallVoidMethod(static_cast<jobject>(invoke_interface),
                        m_invoke_interface_result,
                        new_string(data));
}

extern "C"
JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }

    initialize_jni(vm, env);

    const auto c_tun_interface = find_class("com/follow/clash/core/TunInterface");

    const auto c_invoke_interface = find_class("com/follow/clash/core/InvokeInterface");

    m_tun_interface_protect = find_method(c_tun_interface, "protect", "(I)V");
    m_tun_interface_resolve_process = find_method(c_tun_interface, "resolverProcess",
                                                  "(ILjava/lang/String;Ljava/lang/String;I)Ljava/lang/String;");
    m_invoke_interface_result = find_method(c_invoke_interface, "onResult",
                                            "(Ljava/lang/String;)V");


    protect_func = &call_tun_interface_protect_impl;
    resolve_process_func = &call_tun_interface_resolve_process_impl;
    result_func = &call_invoke_interface_result_impl;
    release_object_func = &release_jni_object_impl;
    free_string_func = &free_string_impl;

    return JNI_VERSION_1_6;
}
#else
extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_startTun(JNIEnv *env, jobject thiz, jint fd, jobject cb,
                                         jstring stack, jstring address, jstring dns) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_stopTun(JNIEnv *env, jobject thiz) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_invokeAction(JNIEnv *env, jobject thiz, jstring data, jobject cb) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_forceGC(JNIEnv *env, jobject thiz) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_updateDNS(JNIEnv *env, jobject thiz, jstring dns) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_setEventListener(JNIEnv *env, jobject thiz, jobject cb) {
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTraffic(JNIEnv *env, jobject thiz,
                                           const jboolean only_statistics_proxy) {
}
extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTotalTraffic(JNIEnv *env, jobject thiz,
                                                const jboolean only_statistics_proxy) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_suspended(JNIEnv *env, jobject thiz, jboolean suspended) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_quickSetup(JNIEnv *env, jobject thiz, jstring init_params_string,
                                           jstring setup_params_string, jobject cb) {
}
#endif
