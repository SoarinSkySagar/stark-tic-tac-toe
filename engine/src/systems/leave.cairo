#[starknet::interface]
pub trait ILeave<T> {
    fn leave(ref self: T);
}

#[dojo::contract]
pub mod leave {
    use super::{ILeave};
    use starknet::{ContractAddress, get_caller_address};
    use engine::models::{Board, Player};

    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct Ended {
        #[key]
        pub match_id: u32,
        pub winner: ContractAddress,
        pub finished: bool,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of ILeave<ContractState> {
        fn leave(ref self: ContractState) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let player_info: Player = world.read_model(player);
            let board: Board = world.read_model(player_info.match_id);

            // Remove the leaving player from the players array.
            let mut remaining: Array<ContractAddress> = array![];
            for p in board.players {
                if p != player {
                    remaining.append(p);
                }
            };

            // New logic: if more than one player remains, continue game.
            if remaining.len() >= 2 {
                // Reassign turn if leaving player had it.
                let mut turn_assigned = false;
                let mut remaining_players = remaining.clone();
                for p in remaining_players {
                    let mut p_info: Player = world.read_model(p);
                    // Assign turn to the first player found.
                    if !turn_assigned {
                        p_info.turn = true;
                        turn_assigned = true;
                    } else {
                        p_info.turn = false;
                    }
                    world.write_model(@p_info);
                };
                // Update board with remaining players.
                let new_board = Board {
                    match_id: board.match_id,
                    players: remaining,
                    empty: board.empty,
                    winner: board.winner,
                    active: board.active,
                    ready: board.ready,
                };
                world.write_model(@new_board);
                // Optionally, emit a specific event indicating a player left.
            } else {
                // End game if less than 2 players remain.
                let zero_address: ContractAddress = 0.try_into().unwrap();
                let winner: ContractAddress = if remaining.len() > 0 {
                    *remaining[0]
                } else {
                    zero_address
                };
                self.end(player_info.match_id, winner, false, remaining);
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"engine")
        }

        fn end(
            ref self: ContractState,
            match_id: u32,
            winner: ContractAddress,
            finished: bool,
            players: Array<ContractAddress>,
        ) {
            let mut world = self.world_default();
            let board: Board = world.read_model(match_id);
            let new_board = Board {
                match_id: board.match_id,
                players: players,
                empty: board.empty,
                winner: winner,
                active: false,
                ready: board.ready,
            };

            // Reset each player's match data.
            for p in board.players {
                let reset: Player = Player {
                    address: p, match_id: 0, marks: array![], turn: false,
                };
                world.write_model(@reset);
            };

            world.write_model(@new_board);
            world.emit_event(@Ended { match_id: board.match_id, winner, finished });
        }
    }
}

