SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: trg_forbid_pos_audit_events_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_forbid_pos_audit_events_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        RAISE EXCEPTION 'pos_audit_events is an append-only forensic log: % is strictly forbidden', TG_OP;
      END;
      $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: drawer_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drawer_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    shift_id uuid NOT NULL,
    event_type character varying NOT NULL,
    amount bigint NOT NULL,
    authorized_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: order_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    name character varying NOT NULL,
    sku character varying,
    qty numeric(12,3) DEFAULT 1.0 NOT NULL,
    unit character varying DEFAULT 'item'::character varying NOT NULL,
    unit_price_cents bigint DEFAULT 0 NOT NULL,
    total_cents bigint DEFAULT 0 NOT NULL,
    modifiers jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    station_ref character varying NOT NULL,
    vertical character varying NOT NULL,
    status character varying DEFAULT 'created'::character varying NOT NULL,
    total_cents bigint DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pos_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pos_audit_events (
    id bigint NOT NULL,
    actor_id uuid NOT NULL,
    event_name character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: pos_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pos_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pos_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pos_audit_events_id_seq OWNED BY public.pos_audit_events.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: shifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shifts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_id uuid NOT NULL,
    cashier_id uuid NOT NULL,
    opening_cash bigint DEFAULT 0 NOT NULL,
    opened_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    closed_at timestamp with time zone,
    counted_cash bigint,
    expected_cash bigint,
    variance bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: staff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    role character varying DEFAULT 'cashier'::character varying NOT NULL,
    pin_hash character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tenders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    method character varying NOT NULL,
    amount_cents bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    idempotency_key character varying NOT NULL,
    reference_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pos_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_audit_events ALTER COLUMN id SET DEFAULT nextval('public.pos_audit_events_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: drawer_events drawer_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drawer_events
    ADD CONSTRAINT drawer_events_pkey PRIMARY KEY (id);


--
-- Name: order_lines order_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_lines
    ADD CONSTRAINT order_lines_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: pos_audit_events pos_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_audit_events
    ADD CONSTRAINT pos_audit_events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: shifts shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_pkey PRIMARY KEY (id);


--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (id);


--
-- Name: tenders tenders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenders
    ADD CONSTRAINT tenders_pkey PRIMARY KEY (id);


--
-- Name: index_drawer_events_on_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_drawer_events_on_event_type ON public.drawer_events USING btree (event_type);


--
-- Name: index_drawer_events_on_shift_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_drawer_events_on_shift_id ON public.drawer_events USING btree (shift_id);


--
-- Name: index_order_lines_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_lines_on_order_id ON public.order_lines USING btree (order_id);


--
-- Name: index_orders_on_station_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_station_ref ON public.orders USING btree (station_ref);


--
-- Name: index_orders_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_status ON public.orders USING btree (status);


--
-- Name: index_orders_on_vertical; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_vertical ON public.orders USING btree (vertical);


--
-- Name: index_pos_audit_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pos_audit_events_on_actor_id ON public.pos_audit_events USING btree (actor_id);


--
-- Name: index_pos_audit_events_on_event_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pos_audit_events_on_event_name ON public.pos_audit_events USING btree (event_name);


--
-- Name: index_shifts_on_cashier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shifts_on_cashier_id ON public.shifts USING btree (cashier_id);


--
-- Name: index_shifts_on_closed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shifts_on_closed_at ON public.shifts USING btree (closed_at);


--
-- Name: index_shifts_on_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shifts_on_device_id ON public.shifts USING btree (device_id);


--
-- Name: index_staff_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_on_role ON public.staff USING btree (role);


--
-- Name: index_tenders_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenders_on_idempotency_key ON public.tenders USING btree (idempotency_key);


--
-- Name: index_tenders_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tenders_on_order_id ON public.tenders USING btree (order_id);


--
-- Name: index_tenders_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tenders_on_status ON public.tenders USING btree (status);


--
-- Name: pos_audit_events trg_pos_audit_events_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pos_audit_events_immutable BEFORE DELETE OR UPDATE ON public.pos_audit_events FOR EACH ROW EXECUTE FUNCTION public.trg_forbid_pos_audit_events_mutation();


--
-- Name: drawer_events fk_rails_39e74567df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drawer_events
    ADD CONSTRAINT fk_rails_39e74567df FOREIGN KEY (shift_id) REFERENCES public.shifts(id);


--
-- Name: tenders fk_rails_709d4d7520; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenders
    ADD CONSTRAINT fk_rails_709d4d7520 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: drawer_events fk_rails_7dc840e860; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drawer_events
    ADD CONSTRAINT fk_rails_7dc840e860 FOREIGN KEY (authorized_by) REFERENCES public.staff(id);


--
-- Name: shifts fk_rails_c4f51c5967; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT fk_rails_c4f51c5967 FOREIGN KEY (cashier_id) REFERENCES public.staff(id);


--
-- Name: order_lines fk_rails_e6c763ee60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_lines
    ADD CONSTRAINT fk_rails_e6c763ee60 FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260918100000');

