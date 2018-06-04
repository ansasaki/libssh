/*
 * init.c - initialization and finalization of the library
 *
 * This file is part of the SSH Library
 *
 * Copyright (c) 2003-2009 by Aris Adamantiadis
 *
 * The SSH Library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at your
 * option) any later version.
 *
 * The SSH Library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with the SSH Library; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
 * MA 02111-1307, USA.
 */

#include "config.h"
#include "libssh/priv.h"
#include "libssh/socket.h"
#include "libssh/dh.h"
#include "libssh/poll.h"
#include "libssh/threads.h"

#ifdef _WIN32
#include <winsock2.h>
#endif

# define _CONSTRUCTOR __attribute__((constructor))
# define _DESTRUCTOR __attribute__((destructor))

#ifdef HAVE_PTHREAD

# include <pthread.h>

#define SSH_STATIC_MUTEX(mutex) \
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER

# define SSH_STATIC_MUTEX_LOCK(mutex) \
    pthread_mutex_lock(&mutex)

# define SSH_STATIC_MUTEX_UNLOCK(mutex) \
    pthread_mutex_unlock(&mutex)

#else /* HAVE_PTHREAD */

# define SSH_STATIC_MUTEX(mutex)
# define SSH_STATIC_MUTEX_LOCK(mutex)
# define SSH_STATIC_MUTEX_UNLOCK(mutex)

#endif /* HAVE_PTHREAD */

SSH_STATIC_MUTEX(ssh_init_mutex);

/* Counter for initializations */
static int _ssh_initialized = 0;

/* Cache the returned value */
static int _ssh_init_ret = 0;

static int _ssh_init(unsigned constructor) {

    int rc = 0;

    if (!constructor) {
        SSH_STATIC_MUTEX_LOCK(ssh_init_mutex);
    }

    _ssh_initialized++;

    if (_ssh_initialized > 1) {
        rc = _ssh_init_ret;
        goto _ret;
    }

    rc = ssh_threads_init();
    if (rc) {
        goto _ret;
    }

    rc = ssh_crypto_init();
    if (rc) {
        goto _ret;
    }

    rc = ssh_socket_init();
    if (rc) {
        goto _ret;
    }

_ret:
    _ssh_init_ret = rc;

    if (!constructor) {
        SSH_STATIC_MUTEX_UNLOCK(ssh_init_mutex);
    }

    return rc;
}

/**
 * @brief Initialize global cryptographic data structures.
 *
 * This functions is automatically called when the library is loaded.
 *
 * @returns             0 on success, -1 if an error occured.
 */
static void _CONSTRUCTOR auto_init(void) {

    int rc;

    rc = _ssh_init(1);

    if (rc < 0) {
        fprintf(stderr, "Error in auto_init()\n");
    }

    return;
}

/**
 * @defgroup libssh The libssh API
 *
 * The libssh library is implementing the SSH protocols and some of its
 * extensions. This group of functions is mostly used to implement a SSH client.
 * Some function are needed to implement a SSH server too.
 *
 * @{
 */

/**
 * @brief Initialize global cryptographic data structures.
 *
 * This function may be ommited if the system supports pthreads.
 * If the library is already initialized, increments the _ssh_initialized
 * counter and return the error code cached in _ssh_init_ret.
 *
 * @returns             0 on success, -1 if an error occured.
 */
int ssh_init(void) {
    return _ssh_init(0);
}

static int _ssh_finalize(unsigned destructor) {

    if (!destructor) {
        SSH_STATIC_MUTEX_LOCK(ssh_init_mutex);
    }

    if (_ssh_initialized == 1) {
        _ssh_initialized = 0;

        if (_ssh_init_ret < 0) {
            goto _ret;
        }

        ssh_crypto_finalize();
        ssh_socket_cleanup();
        /* It is important to finalize threading after CRYPTO because
         * it still depends on it */
        ssh_threads_finalize();

    }
    else {
        if (_ssh_initialized > 0) {
            _ssh_initialized--;
        }
    }

_ret:
    if (!destructor) {
        SSH_STATIC_MUTEX_UNLOCK(ssh_init_mutex);
    }
    return 0;
}

/**
 * @brief Finalize and cleanup all libssh and cryptographic data structures.
 *
 * This function is automatically called when the library is unloaded.
 *
 * @returns             0 on succes, -1 if an error occured.
 *
 */
static void _DESTRUCTOR auto_finalize(void) {

    int rc;

    rc = _ssh_finalize(1);

    if (rc < 0) {
        fprintf(stderr, "Error in auto_finalize()\n");
    }

    return;
}

/**
 * @brief Finalize and cleanup all libssh and cryptographic data structures.
 *
 * This function should only be called once, at the end of the program!
 * When called, decrements the counter _ssh_initialized. If the counter reaches
 * zero, then the libssh and cryptographic data structures are cleaned up.
 *
 * @returns             0 on succes, -1 if an error occured.
 *
 @returns 0 otherwise
 */
int ssh_finalize(void) {
    return _ssh_finalize(0);
}

/** @} */

/* vim: set ts=4 sw=4 et cindent: */
