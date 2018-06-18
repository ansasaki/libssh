/*
 * This file is part of the SSH Library
 *
 * Copyright (c) 2018 by Anderson Toshiyuki Sasaki
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
#include <libssh/callbacks.h>

#ifdef HAVE_WINLOCKS

#include <windows.h>
#include <WinBase.h>
#include <errno.h>

/** @brief Defines the needed callbacks for pthread. Use this if your
 * OS supports libpthread and want to use it for threading.
 * @code
 * #include <libssh/callbacks.h>
 * #include <errno.h>
 * #include <pthread.h>
 * SSH_THREADS_PTHREAD(ssh_pthread_callbacks);
 * int main(){
 *   ssh_init_set_threads_callbacks(&ssh_pthread_callbacks);
 *   ssh_init();
 *   ...
 * }
 * @endcode
 * @param name name of the structure to be declared, containing the
 * callbacks for threading
 *
 */

static int ssh_winlock_mutex_init (void **priv) {
  CRITICAL_SECTION *lock = malloc(sizeof(CRITICAL_SECTION));

  if (lock == NULL) {
    return ENOMEM;
  }

  InitializeCriticalSection(lock);

  *priv = lock;

  return 0;
}

static int ssh_winlock_mutex_destroy (void **lock) {
  DeleteCriticalSection((CRITICAL_SECTION *) * priv);
  free(*priv);

  return 0;
}

static int ssh_winlock_mutex_lock (void **lock) {
  EnterCriticalSection((CRITICAL_SECTION *) * priv);
  return 0;
}

static int ssh_winlock_mutex_unlock (void **lock){
  LeaveCriticalSection((CRITICAL_SECTION *) * priv);
  return 0;
}

static unsigned long ssh_winlock_thread_id (void){
  return GetCurrentThreadId();
}

static struct ssh_threads_callbacks_struct ssh_threads_winlock =
{
    .type = "threads_winlock",
    .mutex_init = ssh_winlock_mutex_init,
    .mutex_destroy = ssh_winlock_mutex_destroy,
    .mutex_lock = ssh_winlock_mutex_lock,
    .mutex_unlock = ssh_winlock_mutex_unlock,
    .thread_id = ssh_winlock_thread_id
};

struct ssh_threads_callbacks_struct *ssh_threads_get_winlock(void) {
  return &ssh_threads_winlock;
}

struct ssh_threads_callbacks_struct *ssh_threads_get_default(void) {
  return &ssh_threads_winlock;
}

#endif /* HAVE_WINLOCKS */
