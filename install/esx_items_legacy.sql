-- Only for old ESX versions (v1 final / 1.2) whose items table uses `limit` instead of `weight`
-- ESX Legacy: use esx_items.sql instead
INSERT INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
    ('police_tape',     'Police Tape',                10, 0, 1),
    ('crimescene_tape', 'Crime Scene Tape',           10, 0, 1),
    ('caution_tape',    'Caution Tape',               10, 0, 1),
    ('fire_tape',       'Fire Line Tape',             10, 0, 1),
    ('ems_tape',        'EMS Tape',                   10, 0, 1),
    ('barrier_tape',    'Barrier Tape (red/white)',   10, 0, 1),
    ('hazard_tape',     'Hazard Tape (yellow/black)', 10, 0, 1);
