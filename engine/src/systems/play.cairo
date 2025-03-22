use engine::models::{Position};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IPlay<T> {
    fn mark(ref self: T, position: Position);
}

#[dojo::contract]
pub mod play {
    use super::{IPlay, Position, array_contains_position, array_contains_address};
    use starknet::{ContractAddress, get_caller_address};
    use engine::models::{Board, Player};

    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct Marked {
        #[key]
        pub player: ContractAddress,
        pub position: Position,
        pub symbol: bool,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct Ended {
        #[key]
        pub match_id: u32,
        pub winner: ContractAddress,
        pub finished: bool,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IPlay<ContractState> {
        fn mark(ref self: ContractState, position: Position) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let mut player_info: Player = world.read_model(player);
            let board: Board = world.read_model(player_info.match_id);

            // Ensure caller is in players array.
            assert(array_contains_address(@board.players, player), 'Not in this match');
            assert(board.active, 'Match no longer active');
            assert(board.ready, 'Match not ready');
            assert(player_info.turn, 'Not your turn');
            assert(array_contains_position(@board.empty, position), 'Position already marked');

            // Remove marked position.
            let mut empty_board: Array<Position> = array![];
            for pos in board.empty {
                if pos != position {
                    empty_board.append(pos);
                }
            };

            // Update current player's marks.
            player_info.marks.append(position);
            // Turn switching: compute next player's index.
            let mut current_index = 0;
            for i in 0..board.players.len() {
                if board.players[i] == @player {
                    current_index = i;
                    break;
                }
            };
            let next_index = (current_index + 1) % board.players.len().into();
            let next_player = board.players[next_index];

            let board_players = board.players.clone();
            //Update turn flags for all players.
            for p in board_players {
                let mut p_info: Player = world.read_model(p);
                if p == player {
                    p_info.turn = false;
                } else if p == *next_player {
                    p_info.turn = true;
                } else {
                    p_info.turn = false;
                }
                world.write_model(@p_info);
            };

            let new_board = Board {
                match_id: board.match_id,
                players: board.players,
                empty: empty_board,
                winner: board.winner,
                active: board.active,
                ready: board.ready,
            };

            world.write_model(@new_board);
            // For backward compatibility, symbol is set true.
            world.emit_event(@Marked { player, position, symbol: true });

            // ...existing win checks...
            let updated_player: Player = world.read_model(player);

            if array_contains_position(@updated_player.marks, Position { i: position.i, j: 1 })
                && array_contains_position(@updated_player.marks, Position { i: position.i, j: 2 })
                && array_contains_position(
                    @updated_player.marks, Position { i: position.i, j: 3 },
                ) {
                self.end(updated_player.match_id, player, true);
            } else if array_contains_position(
                @updated_player.marks, Position { i: 1, j: position.j },
            )
                && array_contains_position(@updated_player.marks, Position { i: 2, j: position.j })
                && array_contains_position(
                    @updated_player.marks, Position { i: 3, j: position.j },
                ) {
                self.end(updated_player.match_id, player, true);
            };

            if position.i == position.j {
                if array_contains_position(@updated_player.marks, Position { i: 1, j: 1 })
                    && array_contains_position(@updated_player.marks, Position { i: 2, j: 2 })
                    && array_contains_position(@updated_player.marks, Position { i: 3, j: 3 }) {
                    self.end(updated_player.match_id, player, true);
                };
            } else if position.i + position.j == 4 {
                if array_contains_position(@updated_player.marks, Position { i: 1, j: 3 })
                    && array_contains_position(@updated_player.marks, Position { i: 2, j: 2 })
                    && array_contains_position(@updated_player.marks, Position { i: 3, j: 1 }) {
                    self.end(updated_player.match_id, player, true);
                };
            };

            let zero_address: ContractAddress = 0.try_into().unwrap();
            if new_board.empty.len() == 0 {
                self.end(updated_player.match_id, zero_address, true);
            };
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"engine")
        }

        fn end(ref self: ContractState, match_id: u32, winner: ContractAddress, finished: bool) {
            let mut world = self.world_default();

            let board: Board = world.read_model(match_id);

            let board_players = board.players.clone();

            let new_board = Board {
                match_id: board.match_id,
                players: board.players,
                empty: board.empty,
                winner,
                active: false,
                ready: true,
            };

            for p in board_players {
                let player = Player { address: p, match_id: 0, marks: array![], turn: false };
                world.write_model(@player);
            };

            world.write_model(@new_board);
            world.emit_event(@Ended { match_id: board.match_id, winner, finished });
        }
    }
}

pub fn array_contains_position(array: @Array<Position>, position: Position) -> bool {
    let mut res = false;
    for i in 0..array.len() {
        if array[i] == @position {
            res = true;
            break;
        }
    };
    res
}

pub fn array_contains_address(array: @Array<ContractAddress>, addr: ContractAddress) -> bool {
    let mut found = false;
    for i in 0..array.len() {
        if array[i] == @addr {
            found = true;
            break;
        }
    };
    found
}

