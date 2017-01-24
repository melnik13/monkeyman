use utf8;
package HyperMouse::Schema::Result::Payment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

HyperMouse::Schema::Result::Payment

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<payment>

=cut

__PACKAGE__->table("payment");

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

=head2 provider_contractor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 client_contractor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 currency_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 sum

  data_type: 'double precision'
  is_nullable: 0

=head2 transaction_handle

  data_type: 'varchar'
  is_nullable: 0
  size: 127

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
  "provider_contractor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "client_contractor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "currency_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "sum",
  { data_type => "double precision", is_nullable => 0 },
  "transaction_handle",
  { data_type => "varchar", is_nullable => 0, size => 127 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 client_contractor

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::Contractor>

=cut

__PACKAGE__->belongs_to(
  "client_contractor",
  "HyperMouse::Schema::Result::Contractor",
  { id => "client_contractor_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);

=head2 currency

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::Currency>

=cut

__PACKAGE__->belongs_to(
  "currency",
  "HyperMouse::Schema::Result::Currency",
  { id => "currency_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);

=head2 provider_contractor

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::Contractor>

=cut

__PACKAGE__->belongs_to(
  "provider_contractor",
  "HyperMouse::Schema::Result::Contractor",
  { id => "provider_contractor_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-01-24 12:14:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AtA+9AoTSp6n9WWWfPYGfA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
