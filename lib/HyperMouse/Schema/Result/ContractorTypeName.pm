use utf8;
package HyperMouse::Schema::Result::ContractorTypeName;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

HyperMouse::Schema::Result::ContractorTypeName

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<contractor_type_name>

=cut

__PACKAGE__->table("contractor_type_name");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 valid_since

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 valid_till

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 removed

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 contrator_type_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 language_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 127

=head2 name_short

  data_type: 'varchar'
  is_nullable: 0
  size: 63

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "valid_since",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "valid_till",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "removed",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "contrator_type_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "language_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 127 },
  "name_short",
  { data_type => "varchar", is_nullable => 0, size => 63 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 contrator_type

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::ContractorType>

=cut

__PACKAGE__->belongs_to(
  "contrator_type",
  "HyperMouse::Schema::Result::ContractorType",
  { id => "contrator_type_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);

=head2 language

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::Language>

=cut

__PACKAGE__->belongs_to(
  "language",
  "HyperMouse::Schema::Result::Language",
  { id => "language_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-01-24 12:14:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xFXSU8D3XT7MSyVwWSw57Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
