module libs::queue {
    use sui::table::Table;
    use sui::table;
    use std::vector::length;
    use std::vector;
    use sui::tx_context::TxContext;

    const EEmptyQueue: u64 = 1;
    const EInsufficientQueue: u64 = 2;

    struct Queue has store {
        first: u64,
        last: u64,
        queue: Table<u64, u256>,
    }

    public fun initialize(queue: &mut Queue) {
        if (queue.first == 0) {
            queue.first = 1;
        }
    }

    public fun enqueue(queue: &mut Queue, item: u256): u64 {
        let last = queue.last + 1;
        queue.last = last;
        if (item != 0) {
            table::add(&mut queue.queue, last, item);
        };
        return last
    }

    public fun dequeue(queue: &mut Queue): u256 {
        let last = queue.last;
        let first = queue.first;
        assert!(i_lenth(last, first) != 0, EEmptyQueue);
        let item = *table::borrow(&mut queue.queue, first);
        if (item != 0) {
            table::remove(&mut queue.queue, first);
        };
        queue.first = first + 1;
        return item
    }

    public fun batch_enqueue(queue: &mut Queue, items: vector<u256>): u64 {
        let last = queue.last;
        let i: u64 = 0;
        loop {
            if (i < length(&items)) {
                last = last + 1;
                let item = *vector::borrow(&items, i);
                if (item != 0) {
                    table::add(&mut queue.queue, last, item);
                };
                i = i + 1;
            } else {
                break
            }
        };
        queue.last = last;
        return last
    }

    public fun batch_dequeue(queue: &mut Queue, num: u64): vector<u256> {
        let last = queue.last;
        let first = queue.first;
        assert!(i_lenth(last, first) >= num, EInsufficientQueue);
        let items: &mut vector<u256> = &mut vector::empty<u256>();
        let i = 0;
        loop {
            if (i < num) {
                vector::push_back(items, *table::borrow(&queue.queue, first));
                table::remove(&mut queue.queue, first);
                first = first + 1;
                i = i + 1;
            } else {
                break
            }
        };
        queue.first = first;
        return *items
    }

    public fun contains(queue: &mut Queue, item: u256): bool {
        let first = queue.first;
        let last= queue.last;
        loop {
            if (first <= last) {
                if (*table::borrow(&queue.queue, first) == item) {
                    return true
                };
                first = first + 1;
            } else {
                break
            }
        };
        return false
    }

    public fun last_item(queue: &mut Queue): u256 {
        *table::borrow(&queue.queue, queue.last)
    }

    public fun peek(queue: &mut Queue): u256 {
        assert!(!is_empty(queue), EEmptyQueue);
        *table::borrow(&queue.queue, queue.first)
    }

    fun is_empty(queue: &mut Queue): bool {
        queue.last < queue.first
    }

    public fun lenth(queue: &mut Queue): u64 {
        let last = queue.last;
        let first = queue.first;
        return i_lenth(last, first)
    }

    fun i_lenth(last: u64, first: u64): u64 {
        return last + 1 - first
    }

    public fun create_queue(ctx: &mut TxContext): Queue {
        Queue {
            first: 1,
            last: 0,
            queue: table::new(ctx)
        }
    }
}
