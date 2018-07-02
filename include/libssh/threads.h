/*
 * This file is part of the SSH Library
 *
 * Copyright (c) 2010 by Aris Adamantiadis
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#ifndef THREADS_H_
#define THREADS_H_

#include <libssh/libssh.h>
#include <libssh/callbacks.h>

#ifdef HAVE_PTHREAD

#include <pthread.h>
#define SSH_STATIC_MUTEX(mutex) \
    static pthread_mutex_t mutex

#elif defined(HAVE_WINLOCKS)

#include <windows.h>
#include <WinBase.h>
# define SSH_STATIC_MUTEX(mutex) \
    static CRITICAL_SECTION *mutex = NULL

#else

# define SSH_STATIC_MUTEX(mutex) \
    static void *mutex

#endif

int ssh_threads_init(void);
void ssh_threads_finalize(void);
const char *ssh_threads_get_type(void);

void ssh_static_mutex_init(void **mutex);
void ssh_mutex_init(void **mutex);
void ssh_mutex_lock(void **mutex);
void ssh_mutex_unlock(void **mutex);
void ssh_mutex_destroy(void **mutex);

struct ssh_threads_callbacks_struct *ssh_threads_get_default(void);
int crypto_thread_init(struct ssh_threads_callbacks_struct *user_callbacks);
void crypto_thread_finalize(void);

#endif /* THREADS_H_ */
