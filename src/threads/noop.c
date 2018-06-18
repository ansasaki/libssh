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
#include "libssh/threads.h"
#include <libssh/callbacks.h>

static int threads_noop (void **lock){
    (void)lock;
  return 0;
}

static unsigned long threads_id_noop (void){
    return 1;
}

static struct ssh_threads_callbacks_struct ssh_threads_noop =
{
    "threads_noop",
    threads_noop,
    threads_noop,
    threads_noop,
    threads_noop,
    threads_id_noop
};

struct ssh_threads_callbacks_struct *ssh_threads_get_noop(void) {
    return &ssh_threads_noop;
}

struct ssh_threads_callbacks_struct *ssh_threads_get_default(void) {
    return &ssh_threads_noop;
}
